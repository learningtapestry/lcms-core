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
#              ├── every material the lesson's activities list (Google Docs)
#              └── files from the Non-LCMS lesson folder (copies)
#
# Folder names come from the Non-LCMS Root Folder (see DigitalAccess::Layout).
# Regenerating updates the same folders and documents in place; copies of
# Non-LCMS files are refreshed when their original changes and removed when it
# is gone.
#
# The lesson and material documents are exported by nested DocumentGdocJob /
# MaterialGdocJob runs; this job then exports the unit document and copies the
# Non-LCMS files. It stores the unit folder's link in the unit's `links`:
#  {"digital_access" => {"gdoc" => {"url" => URL, "status" => "completed", "timestamp" => 1769045090}}}
#
class DigitalAccessBundleJob < BaseBundleJob
  include UnitLevelJob

  CONTENT_TYPE = :digital_access
  NESTED_JOBS = %w(DocumentGdocJob MaterialGdocJob DigitalAccessBundleJob).freeze
  LINK_KEY = "gdoc"

  class ConfigurationError < StandardError; end

  queue_as :default

  def perform(entry_id, options = {})
    perform_generation_for(entry_id, options)
  end

  private

  def generate_dependants
    unit_node = layout.children.first
    export_materials(unit.unit_materials, unit_node.folder_id)

    unit_node.children.each do |section_node|
      export_materials(section_node.record.section_materials, section_node.folder_id)

      section_node.children.each do |lesson_node|
        DocumentGdocJob.perform_later(lesson_node.record.id, job_options(lesson_node.folder_id))
        export_materials(lesson_node.record.lesson_materials, lesson_node.folder_id)
      end
    end
  end

  def generate_bundle
    course_node = layout
    unit_node = course_node.children.first
    Exporters::Gdoc::Unit.new(unit, folder_id: unit_node.folder_id).export
    sync_non_lcms_files(course_node)

    url = Exporters::Gdoc::Base.url_for(unit_node.folder_id)
    unit.reload.with_lock do
      data = { CONTENT_TYPE.to_s => { LINK_KEY => { timestamp: Time.current.to_i, status: "completed", url: } } }
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

  # Copies each Non-LCMS folder's files into its bundle folder, at every level.
  def sync_non_lcms_files(node)
    drive.sync_copies(node.source_id, node.folder_id)
    node.children.each { sync_non_lcms_files(it) }
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
