# frozen_string_literal: true

#
# Job to generate a PDF bundle for a unit including all dependent lesson PDFs
#
# The basic structure of the folder inside the AWS S3 bucket is as follows:
#
#  UnitName
#  ├── UnitName.pdf (unit document: cover, ...)
#  ├── LessonNameX.pdf
#  ├── LessonNameY.pdf
#  ├── ...
#  ├── materials
#  │   ├── MaterialNameX.pdf
#  │   ├── MaterialNameY.pdf
#  │   └── ...
#
# It stores the links inside the ` links ` field of the unit record.
# The format of the data is:
#  {"unit_bundle" =>
#    {"pdf" =>
#      {"url" => URL,                 (the unit document: the Teacher Bundle to Print PDF)
#       "folder_url" => URL,          (the bundle folder)
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
  PDF_OPTION_KEYS = %i(renderer accessible_pdf accessibility).freeze

  queue_as :default

  def perform(entry_id, options = {})
    perform_generation_for(entry_id, options)
  end

  private

  #
  # Renders the unit document and copies the generated lesson and material PDFs
  # to the bundle folder in S3
  #
  def generate_bundle
    bundle_folder = unit.bundle_folder(CONTENT_TYPE)

    url = upload_unit_document(bundle_folder:)

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

    # Store bundle generation timestamp in unit links. The url is the PDF
    # itself: S3 has no folder page to open.
    unit.reload.with_lock do
      data = {
        CONTENT_TYPE.to_s => {
          LINK_KEY => { timestamp: Time.current.to_i, status: "completed", url:,
                        folder_url: S3Service.url_for(bundle_folder) }
        }
      }
      links = unit.links.deep_merge(data)
      unit.update links: links
    end

    url
  end

  # Renders the unit document (Teacher Edition front matter) into the bundle
  # folder. Unlike the lesson/material copies below, a failure here is not
  # swallowed: a bundle without its cover must not be reported as completed.
  # @return [String] the PDF's URL
  def upload_unit_document(bundle_folder:)
    pdf = Exporters::Pdf::Unit.new(unit, options.slice(*PDF_OPTION_KEYS)).export
    S3Service.upload("#{bundle_folder}/#{unit.pdf_filename}", pdf, content_type: "application/pdf")
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

  # The unit PDF does not use these lesson and material PDFs; see
  # docs/technical-debt.md.
  def generate_dependants
    generate_lessons
    generate_materials
  end

  def generate_lessons
    unit.lessons.each do |lesson|
      DocumentPdfJob.perform_later(lesson.id, pdf_job_options)
    end
  end

  def generate_materials
    unit.materials.each do |material|
      MaterialPdfJob.perform_later(material.id, pdf_job_options)
    end
  end

  def pdf_job_options
    {
      content_type: CONTENT_TYPE.to_s,
      initial_job_id: initial_job_id
    }.merge(options.slice(*PDF_OPTION_KEYS))
  end
end
