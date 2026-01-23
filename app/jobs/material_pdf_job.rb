# frozen_string_literal: true

class MaterialPdfJob < ApplicationJob
  include MaterialRescuableJob
  include ResqueJob

  queue_as :default

  LINK_KEY = "pdf"

  # Generates a PDF file for a material and uploads it to S3.
  #
  # This job performs the following steps:
  # 1. Fetches the material record and wraps it in a presenter
  # 2. Exports the material content to PDF format
  # 3. Generates a thumbnail image from the PDF
  # 4. Uploads both PDF and thumbnail to S3
  # 5. Updates the material record with the generated links
  #
  # @param entry_id [Integer] the ID of the Material record to process
  # @param options [Hash] optional parameters for PDF generation
  # @option options [String, Symbol] :content_type the type of content to export
  #   (:unit_bundle)
  # @option options [String] :folder the S3 folder path prefix for storing files
  # @option options [Boolean] :preview when true, stores links in preview_links
  #   instead of links attribute (skips page count calculation)
  #
  # @return [void]
  def perform(entry_id, options = {})
    options = options.with_indifferent_access
    content_type = options[:content_type].to_sym
    entry = Material.find(entry_id)
    material = MaterialPresenter.new(entry, content_type:)

    pdf = ::Exporters::Pdf::Material.new(material, options).export
    thumb = ::Exporters::Thumbnail.new(pdf).export

    s3_path = ""
    s3_path += "#{options[:folder]}/" if options[:folder].present?
    s3_path += "materials"

    pdf_filename = "#{s3_path}/#{material.pdf_filename}"
    thumb_filename = "#{s3_path}/#{material.base_filename}.jpg"

    pdf_url = S3Service.upload(pdf_filename, pdf, content_type: "application/pdf")
    thumb_url = S3Service.upload(thumb_filename, thumb, content_type: "image/jpeg")

    pages = ::CombinePDF.parse(pdf).pages.size rescue 0 unless options[:preview]

    material.with_lock do
      if options[:preview]
        data = {
          content_type.to_s => {
            LINK_KEY => {
              url: pdf_url,
              timestamp: Time.current.to_i,
              pages: pages || -1,
              thumb_url:
            }
          }
        }
        material.update preview_links: material.reload.preview_links.merge(data)
      else
        data = {
          content_type.to_s => {
            LINK_KEY => {
              url: pdf_url,
              timestamp: Time.current.to_i,
              pages: pages || -1,
              thumb_url:
            }
          }
        }
        material.update links: material.reload.links.deep_merge(data)
      end
    end
  end
end
