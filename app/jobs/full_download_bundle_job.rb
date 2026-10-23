# frozen_string_literal: true

require "zip"

#
# Generates a unit's Full Unit Content for Download: one zip file holding the
# same tree as the Teacher Bundle for Digital Access, with PDFs in place of
# Google Docs:
#
#  <root>                           (admin Settings > Bundles)
#  └── <course>
#      ├── files from the top of the Non-LCMS Root Folder
#      └── <unit>
#          ├── the Teacher Bundle to Print (PDF)
#          ├── Unit Materials (PDF)
#          ├── files from the Non-LCMS unit folder
#          └── <section> (one per section)
#              ├── Section Materials (PDF)
#              ├── files from the Non-LCMS section folder
#              └── <lesson> (one per lesson)
#                  ├── the lesson (PDF)
#                  ├── every material the lesson's activities list (PDF)
#                  └── files from the Non-LCMS lesson folder
#
# Folder names come from the Non-LCMS Root Folder (see DigitalAccess::Layout).
# Non-LCMS files go in as they are; Google Docs, Sheets and Slides among them
# are exported to Word, Excel and PowerPoint (see DigitalAccess::Drive#download).
#
# The lesson and material PDFs are rendered by nested DocumentPdfJob /
# MaterialPdfJob runs; this job then renders the Teacher Bundle to Print,
# builds the zip and uploads it to S3. It stores the zip's link in the unit's
# `links`:
#  {"full_download" => {"zip" => {"url" => URL, "status" => "completed", "timestamp" => 1769045090}}}
#
class FullDownloadBundleJob < BaseBundleJob
  include UnitLevelJob

  CONTENT_TYPE = :full_download
  NESTED_JOBS = %w(DocumentPdfJob MaterialPdfJob FullDownloadBundleJob).freeze
  LINK_KEY = "zip"
  PDF_OPTION_KEYS = UnitBundlePdfJob::PDF_OPTION_KEYS

  queue_as :default

  def perform(entry_id, options = {})
    perform_generation_for(entry_id, options)
  end

  private

  # Notes when the PDFs were queued (carried to the requeued run in its
  # options), so #stored_pdf can tell a PDF from this run from one a failed
  # nested job left behind from an earlier run.
  def generate_dependants
    options[:dependants_queued_at] = Time.current.to_i
    lessons = unit.sections.flat_map(&:lessons)
    lessons.each { DocumentPdfJob.perform_later(it.id, pdf_job_options) }

    materials = unit.unit_materials + unit.sections.flat_map(&:section_materials) + lessons.flat_map(&:lesson_materials)
    materials.uniq(&:id).each { MaterialPdfJob.perform_later(it.id, pdf_job_options) }
  end

  def generate_bundle
    url = Tempfile.create(%w(full_download .zip), binmode: true) do |file|
      write_zip(file.path)
      S3Service.upload("#{unit.bundle_folder(CONTENT_TYPE)}.zip", file, content_type: "application/zip")
    end

    unit.reload.with_lock do
      data = { CONTENT_TYPE.to_s => { LINK_KEY => { timestamp: Time.current.to_i, status: "completed", url: } } }
      unit.update links: unit.links.deep_merge(data)
    end
    url
  end

  def write_zip(path)
    course_node = DigitalAccess::Layout.new(unit, drive:, output_root_id: nil, source_root_id:).build
    unit_node = course_node.children.first
    @missing_pdfs = []

    Zip::OutputStream.open(path) do |zip|
      writer = ZipWriter.new(zip)
      course_path = writer.folder(root_name, course_node.name)
      add_non_lcms_files(writer, course_path, course_node)

      unit_path = writer.folder(course_path, unit_node.name)
      writer.file(unit_path, unit.pdf_filename, Exporters::Pdf::Unit.new(unit, options.slice(*PDF_OPTION_KEYS)).export)
      add_pdfs(writer, unit_path, unit.unit_materials)
      add_non_lcms_files(writer, unit_path, unit_node)

      unit_node.children.each do |section_node|
        section_path = writer.folder(unit_path, section_node.name)
        add_pdfs(writer, section_path, section_node.record.section_materials)
        add_non_lcms_files(writer, section_path, section_node)

        section_node.children.each do |lesson_node|
          lesson_path = writer.folder(section_path, lesson_node.name)
          lesson = lesson_node.record
          add_pdfs(writer, lesson_path, [lesson, *lesson.lesson_materials])
          add_non_lcms_files(writer, lesson_path, lesson_node)
        end
      end
    end

    raise "PDFs failed to generate for: #{@missing_pdfs.uniq.join(', ')}" if @missing_pdfs.any?
  end

  # Lesson and material PDFs. One whose nested job stored no PDF is noted and
  # fails the bundle once the zip is written, naming every missing file.
  def add_pdfs(writer, path, records)
    records.each do |record|
      data = stored_pdf(record)
      data ? writer.file(path, record.pdf_filename, data) : @missing_pdfs << record.pdf_filename
    end
  end

  # The node's Non-LCMS files (not its sub-folders: those are matched to
  # sections and lessons). A file Drive cannot hand over (a Form, a shortcut)
  # or that fails to download is left out rather than failing the bundle.
  def add_non_lcms_files(writer, path, node)
    return if node.source_id.nil?

    drive.children(node.source_id).reject(&:folder).each do |item|
      name, data = drive.download(item)
      writer.file(path, name, data) if name
    rescue Google::Apis::Error => e
      Rails.logger.warn("Full Unit Content for Download: skipped #{item.name} (#{item.id}): #{e.message}")
    end
  end

  # The PDF the nested job stored for this lesson or material during this run;
  # nil when there is none, or only an older one (the job failed this time).
  def stored_pdf(record)
    entry = record.reload.links.dig(CONTENT_TYPE.to_s, "pdf") || {}
    queued_at = options[:dependants_queued_at]
    return if entry["url"].blank? || (queued_at && entry["timestamp"].to_i < queued_at)

    S3Service.read_data_from_s3(URI.parse(entry["url"]))
  end

  def pdf_job_options
    { content_type: CONTENT_TYPE.to_s, initial_job_id: }.merge(options.slice(*PDF_OPTION_KEYS))
  end

  def root_name
    settings[:download_root_name].to_s.strip.presence || I18n.t("full_download.root")
  end

  def source_root_id
    DigitalAccess::Drive.folder_id_for(settings[:non_lcms_root_url]).presence
  end

  def settings
    @settings ||= Settings.get(:bundles, include_defaults: true) || {}
  end

  def drive
    @drive ||= DigitalAccess::Drive.new(Google::DriveService.new(unit, {}).service)
  end

  #
  # Adds folders and files to the zip under names that are safe for a file
  # system ("/" in a Drive name would make a sub-folder) and unique within
  # their folder ("Notes.pdf", "Notes (2).pdf").
  #
  class ZipWriter
    def initialize(zip)
      @zip = zip
      @taken = Hash.new { |hash, key| hash[key] = Set.new }
    end

    # @return [String] the folder's path in the zip
    def folder(parent, name)
      [parent, unique(parent, name)].compact_blank.join("/")
    end

    def file(folder, name, data)
      @zip.put_next_entry("#{folder}/#{unique(folder, name)}")
      @zip.write(data)
    end

    private

    def unique(folder, name)
      name = name.to_s.tr("/\\", "--").gsub(/[[:cntrl:]]/, "").strip.presence || "untitled"
      base = File.basename(name, ".*")
      ext = File.extname(name)
      candidate = name
      n = 1
      candidate = "#{base} (#{n += 1})#{ext}" while @taken[folder].include?(candidate.downcase)
      @taken[folder] << candidate.downcase
      candidate
    end
  end
end
