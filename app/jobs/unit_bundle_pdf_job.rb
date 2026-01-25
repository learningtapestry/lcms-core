# frozen_string_literal: true

#
# Job to generate a PDF bundle for a unit including all dependent lesson PDFs
#
# The basic structure of the folder inside the AWS S3 bucket is as follows:
#
#  UnitName
#  ├── LessonNameX.pdf
#  ├── LessonNameY.pdf
#  ├── ...
#  ├── materials
#  │   ├── MaterialNameX.pdf
#  │   ├── MaterialNameY.pdf
#  │   └── ...
#
# It stores the link to the AWS S3 folder inside the ` links ` field of the unit record.
# The format of the data is:
#  {"unit_bundle" =>
#    {"pdf" =>
#      {"url" => URL,
#       "status" => "completed",
#       "timestamp" => 1769045090}
#    }
#  }
#
class UnitBundlePdfJob < BaseBundleJob
  include UnitLevelJob

  CONTENT_TYPE = :unit_bundle
  NESTED_JOBS = %w(DocumentPdfJob MaterialPdfJob UnitBundlePdfJob).freeze
  LINK_KEY = "pdf"

  queue_as :default

  def perform(entry_id, options = {})
    perform_generation_for(entry_id, options)
  end

  private

  #
  # Copies the generated lesson PDFs to the bundle folder in S3
  #
  def generate_bundle
    bundle_folder = unit.bundle_folder(CONTENT_TYPE)

    # Copy lesson PDFs to the bundle folder
    unit.lessons.each do |lesson|
      source_url = lesson.links.dig(CONTENT_TYPE.to_s, LINK_KEY, "url")
      next if source_url.blank?

      copy_pdf_to_bundle(source_url:, bundle_folder:, filename: lesson.pdf_filename)
    end

    # Copy material PDFs to the bundle folder
    unit.materials.each do |material|
      source_url = material.links.dig(CONTENT_TYPE.to_s, LINK_KEY, "url")
      next if source_url.blank?

      filename = "materials/#{material.pdf_filename}"
      copy_pdf_to_bundle(source_url:, bundle_folder:, filename:)
    end

    # Generate the bundle folder URL
    url = S3Service.url_for(bundle_folder)

    # Store bundle generation timestamp in unit links
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

  # Copies a PDF from the source URL to the bundle folder in S3
  def copy_pdf_to_bundle(source_url:, bundle_folder:, filename:)
    uri = URI.parse(source_url)
    pdf_data = S3Service.read_data_from_s3(uri)
    target_key = "#{bundle_folder}/#{filename}"
    S3Service.upload(target_key, pdf_data, content_type: "application/pdf")
  rescue StandardError => e
    Rails.logger.error "Failed to copy PDF #{source_url} to bundle: #{e.message}"
  end

  def generate_dependants
    generate_lessons
    generate_materials
  end

  def generate_lessons
    unit.lessons.each do |lesson|
      job_options = {
        content_type: CONTENT_TYPE.to_s,
        initial_job_id: initial_job_id
      }
      DocumentPdfJob.perform_later(lesson.id, job_options)
    end
  end

  def generate_materials
    unit.materials.each do |material|
      job_options = {
        content_type: CONTENT_TYPE.to_s,
        initial_job_id: initial_job_id
      }
      MaterialPdfJob.perform_later(material.id, job_options)
    end
  end
end
