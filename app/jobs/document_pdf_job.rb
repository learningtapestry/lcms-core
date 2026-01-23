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
  # 5. Updates the document record with the generated link (unless excludes option is set)
  #
  # @param entry_id [Integer] the ID of the Document record to process
  # @param options [Hash] parameters for PDF generation
  # @option options [String, Symbol] :content_type the type of content to export
  #   (:unit_bundle)
  # @option options [String] :filename custom S3 path for the PDF file
  #   (defaults to standard path based on document's pdf_filename)
  # @option options [Array] :excludes when present, skips updating document links
  #
  # @return [void]
  def perform(entry_id, options)
    entry = Document.find(entry_id)
    content_type = options[:content_type].to_sym
    document = DocumentPresenter.new(entry, content_type:)
    filename = options[:filename].presence || "documents/#{document.pdf_filename}"
    pdf = Exporters::Pdf::Document.new(document, options).export
    url = S3Service.upload(filename, pdf, content_type: "application/pdf")

    return if options[:excludes].present?

    document.with_lock do
      data = {
        content_type.to_s => {
          LINK_KEY => { timestamp: Time.current.to_i, url: }
        }
      }

      document.update links: document.reload.links.deep_merge(data)
    end
  end
end
