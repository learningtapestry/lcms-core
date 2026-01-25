# frozen_string_literal: true

class DocumentPdfJob < ApplicationJob
  include DocumentRescuableJob
  include ResqueJob

  queue_as :default

  LINK_KEY = "pdf"

  # Generates a PDF file for a document and uploads it to S3.
  #
  # This job performs the following steps:
  # 1. Fetches the document record and wraps it in a presenter
  # 2. Selects the appropriate PDF exporter based on content type
  # 3. Exports the document content to PDF format
  # 4. Uploads the PDF to S3
  # 5. Updates the document record with the generated link
  #
  # @param entry_id [Integer] the ID of the Document record to process
  # @param options [Hash] parameters for PDF generation
  # @option options [String, Symbol] :content_type the type of content to export
  #   (:unit_bundle)
  # @option options [String] :folder the S3 folder path prefix for storing files
  # @option options [Boolean] :preview when true, stores links in preview_links
  #   instead of links attribute (skips page count calculation)
  #
  # @return [void]
  def perform(entry_id, options)
    entry = Document.find(entry_id)
    content_type = options[:content_type].to_sym
    document = DocumentPresenter.new(entry, content_type:)

    pdf = Exporters::Pdf::Document.new(document, options).export

    s3_path = ""
    s3_path += "#{options[:folder]}/" if options[:folder].present?
    s3_path += "documents"

    filename = "#{s3_path}/#{document.pdf_filename}"

    url = S3Service.upload(filename, pdf, content_type: "application/pdf")

    pages = ::CombinePDF.parse(pdf).pages.size rescue 0 unless options[:preview]

    data = {
      content_type.to_s => {
        LINK_KEY => {
          url:,
          timestamp: Time.current.to_i,
          pages: pages || -1
        }
      }
    }

    document.with_lock do
      if options[:preview]
        document.update preview_links: document.reload.preview_links.deep_merge(data)
      else
        document.update links: document.reload.links.deep_merge(data)
      end
    end
  end
end
