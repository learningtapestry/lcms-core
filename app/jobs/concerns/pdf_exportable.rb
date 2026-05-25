# frozen_string_literal: true

# Shared PDF exporter selection for jobs that render content to PDF.
#
# Each including job declares its default (Grover/Chromium) exporter:
#
#   class DocumentPdfJob < ApplicationJob
#     include PdfExportable
#     pdf_exporter ::Exporters::Pdf::Document
#   end
#
# and renders via:
#
#   pdf = pdf_exporter_class.new(presenter, options).export
#
module PdfExportable
  extend ActiveSupport::Concern

  class_methods do
    # Declares the default (Grover/Chromium) PDF exporter for this job.
    def pdf_exporter(klass)
      @pdf_exporter = klass
    end

    def default_pdf_exporter
      @pdf_exporter
    end
  end

  private

  # Spike toggle: when PDF_VIA_GDOC_EXPORT is set, render the PDF by creating a
  # Google Doc and exporting it via the Drive API instead of Grover/Chromium.
  def pdf_exporter_class
    if ENV["PDF_VIA_GDOC_EXPORT"].present?
      ::Exporters::Pdf::ViaGdoc
    else
      self.class.default_pdf_exporter
    end
  end
end
