# frozen_string_literal: true

#
# Job to generate a Google Docs bundle for a unit including all dependent lesson and material GDocs
#
# The basic structure of the folder inside Google Drive (GOOGLE_APPLICATION_FOLDER_ID) is as follows:
#
#  bundles
#  └── unit_bundle
#      └── UnitName (s3_folder)
#          ├── LessonNameX (Google Doc)
#          ├── LessonNameY (Google Doc)
#          ├── ...
#          └── materials
#              ├── MaterialNameX (Google Doc)
#              ├── MaterialNameY (Google Doc)
#              └── ...
#
# It stores the link to the Google Drive folder inside the `links` field of the unit record.
# The format of the data is:
#  {"unit_bundle" =>
#    {"gdoc" =>
#      {"url" => URL,
#       "status" => "completed",
#       "timestamp" => 1769045090}
#    }
#  }
#
class UnitBundleGdocJob < BaseBundleJob
  include UnitLevelJob

  CONTENT_TYPE = :unit_bundle
  NESTED_JOBS = %w(DocumentGdocJob MaterialGdocJob UnitBundleGdocJob).freeze
  LINK_KEY = "gdoc"

  BUNDLE_FOLDER = "bundles"

  queue_as :default

  # Generates a Google Docs bundle for the specified unit.
  #
  # @param entry_id [Integer] the ID of the Resource (unit) record
  # @param options [Hash] generation options passed to child jobs
  # @return [void]
  def perform(entry_id, options = {})
    perform_generation_for(entry_id, options)
  end

  private

  # Creates the folder structure in Google Drive and stores the bundle URL.
  #
  # @return [String] the Google Drive URL for the bundle folder
  def generate_bundle
    url = Exporters::Gdoc::Base.url_for(unit_folder_id)

    unit.reload.with_lock do
      data = {
        CONTENT_TYPE.to_s => {
          LINK_KEY => { timestamp: Time.current.to_i, status: "completed", url: }
        }
      }
      links = unit.links.deep_merge(data)
      unit.update links: links
    end

    url
  end

  # Enqueues jobs for all dependent resources (lessons and materials).
  #
  # @return [void]
  def generate_dependants
    generate_lessons
    generate_materials
  end

  # Enqueues DocumentGdocJob for each lesson in the unit.
  #
  # @return [void]
  def generate_lessons
    unit.lessons.each do |lesson|
      job_options = {
        content_type: CONTENT_TYPE.to_s,
        initial_job_id: initial_job_id,
        folder_id: unit_folder_id
      }
      DocumentGdocJob.perform_later(lesson.id, job_options)
    end
  end

  # Creates a materials subfolder and enqueues MaterialGdocJob for each material.
  #
  # @return [void]
  def generate_materials
    materials_folder_id = drive_service.create_folder("materials", unit_folder_id)
    unit.materials.each do |material|
      job_options = {
        content_type: CONTENT_TYPE.to_s,
        initial_job_id: initial_job_id,
        folder_id: materials_folder_id
      }
      MaterialGdocJob.perform_later(material.id, job_options)
    end
  end

  #
  # Returns the Google Drive folder ID for the unit bundle
  # Creates the folder structure if it doesn't exist:
  # GOOGLE_APPLICATION_FOLDER_ID/bundles/unit_bundle/{s3_folder}
  #
  # @return [String] the ID of the unit bundle folder
  #
  def unit_folder_id
    @unit_folder_id ||=
      begin
        bundles_id = drive_service.create_folder(BUNDLE_FOLDER)
        unit_bundle_id = drive_service.create_folder(CONTENT_TYPE.to_s, bundles_id)
        drive_service.create_folder(unit.s3_folder, unit_bundle_id)
      end
  end

  # Returns a Google Drive service instance for folder operations.
  #
  # @return [Google::DriveService] the drive service instance
  def drive_service
    @drive_service ||= Google::DriveService.new(unit, {})
  end
end
