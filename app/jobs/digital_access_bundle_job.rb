# frozen_string_literal: true

#
# Generates a unit's Teacher Bundle for Digital Access: a tree of Google Drive
# folders inside the Digital Access Root Folder (admin Settings > Bundles):
#
#  <course>
#  ├── files from the top of the Non-LCMS Root Folder (copies)
#  └── <unit>
#      ├── the Teacher Bundle to Print (Google Doc)
#      ├── Unit Materials (Google Docs)
#      ├── files from the Non-LCMS unit folder (copies)
#      └── <section> (one per section)
#          ├── Section Materials (Google Docs)
#          ├── files from the Non-LCMS section folder (copies)
#          └── <lesson> (one per lesson)
#              ├── the lesson (Google Doc)
#              ├── every other material the lesson's activities list (Google Docs)
#              ├── files from the Non-LCMS lesson folder (copies)
#              └── <unit id>_G<grade>_<lesson number>_Sample_Student_Responses
#                  └── the lesson's response materials (PDF)
#
# Folder names come from the Non-LCMS Root Folder (see DigitalAccess::Layout).
# Regenerating updates the same folders and documents in place; copies of
# Non-LCMS files are refreshed when their original changes and removed when it
# is gone. A file Drive refuses to copy is left out; the link lists those under
# "skipped", and the bundle status page shows them.
#
# The lesson and material documents are exported by nested DocumentGdocJob /
# MaterialGdocJob runs, the response PDFs by MaterialPdfJob runs; this job then
# exports the unit document, uploads the response PDFs and copies the Non-LCMS
# files. It stores the unit folder's link in the unit's `links`:
#  {"digital_access" => {"gdoc" => {"url" => URL, "status" => "completed", "timestamp" => 1769045090,
#                                   "skipped" => [{"folder" => ..., "file" => ..., "reason" => ...}]}}}
#
class DigitalAccessBundleJob < BaseBundleJob
  include UnitLevelJob
  include BundleFiles

  CONTENT_TYPE = :digital_access
  NESTED_JOBS = %w(DocumentGdocJob MaterialGdocJob MaterialPdfJob DigitalAccessBundleJob).freeze
  LINK_KEY = "gdoc"

  class ConfigurationError < StandardError; end

  queue_as :default

  def perform(entry_id, options = {})
    perform_generation_for(entry_id, options)
  end

  private

  def generate_dependants
    note_pdfs_queued
    unit_node = layout.children.first
    export_materials(unit.unit_materials, unit_node.folder_id)

    unit_node.children.each do |section_node|
      export_materials(section_node.record.section_materials, section_node.folder_id)

      section_node.children.each do |lesson_node|
        DocumentGdocJob.perform_later(lesson_node.record.id, job_options(lesson_node.folder_id))
        responses, materials = lesson_node.record.lesson_materials.partition(&:response?)
        export_materials(materials, lesson_node.folder_id)
        responses.each { MaterialPdfJob.perform_later(it.id, pdf_job_options) }
      end
    end
  end

  def generate_bundle
    course_node = layout
    unit_node = course_node.children.first
    Exporters::Gdoc::Unit.new(unit, folder_id: unit_node.folder_id).export
    upload_responses(unit_node)
    sync_non_lcms_files(course_node)

    url = Exporters::Gdoc::Base.url_for(unit_node.folder_id)
    unit.reload.with_lock do
      link = { timestamp: Time.current.to_i, status: "completed", url:, skipped: skipped_files }
      data = { CONTENT_TYPE.to_s => { LINK_KEY => link } }
      unit.update links: unit.links.deep_merge(data)
    end
    url
  end

  def export_materials(materials, folder_id)
    materials.each { MaterialGdocJob.perform_later(it.id, job_options(folder_id)) }
  end

  def job_options(folder_id)
    { content_type: CONTENT_TYPE.to_s, initial_job_id:, folder_id: }
  end

  # Puts each lesson's response PDFs (rendered by the nested MaterialPdfJob
  # runs) in its Sample Student Responses folder. Fails naming every response
  # without a PDF from this run.
  def upload_responses(unit_node)
    missing = []
    unit_node.children.flat_map(&:children).each do |lesson_node|
      lesson = lesson_node.record
      responses = lesson.lesson_materials.select(&:response?)
      next if responses.empty?

      pdfs = responses.to_h do |material|
        data = stored_pdf(material)
        missing << material.pdf_filename unless data
        [material.id, [material.pdf_filename, data]]
      end
      next if missing.any?

      drive.sync_pdfs(drive.folder(lesson.sample_responses_folder_name, lesson_node.folder_id), pdfs)
    end
    raise "PDFs failed to generate for: #{missing.uniq.join(', ')}" if missing.any?
  end

  # Copies each Non-LCMS folder's files into its bundle folder, at every level.
  def sync_non_lcms_files(node, path = nil)
    path = [path, node.name].compact.join("/")
    drive.sync_copies(node.source_id, node.folder_id).each { |item, reason| skip_file(path, item.name, reason) }
    node.children.each { sync_non_lcms_files(it, path) }
  end

  # @return [DigitalAccess::Layout::Node] the course folder node
  def layout
    @layout ||= DigitalAccess::Layout.new(unit, drive:, output_root_id:, source_root_id:).build
  end

  def output_root_id
    DigitalAccess::Drive.folder_id_for(settings[:digital_access_root_url]).presence ||
      raise(ConfigurationError, I18n.t("digital_access.errors.no_root"))
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
end
