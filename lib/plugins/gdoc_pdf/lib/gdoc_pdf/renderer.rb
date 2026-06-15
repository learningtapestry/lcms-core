# frozen_string_literal: true

module GdocPdf
  #
  # PDF renderer that exports the record's Google Doc to PDF.
  #
  # Implements Exporters::Pdf::Renderers::Base. Unlike HTML-based renderers,
  # `#call` ignores the rendered HTML it is handed: the whole point is to
  # export the *real* Google Doc (with its Apps-Script-applied headers/footers
  # and Docs layout), so the rendered HTML is the wrong artifact. The record
  # itself arrives via `options.source`, threaded in by Exporters::Pdf::Base.
  #
  # Capabilities are intentionally empty: Google Docs' PDF export is not
  # PDF/UA-1 certifiable, so the renderer advertises no accessibility
  # capability and the registry refuses :gdoc_pdf + :tagged / :pdf_ua
  # requests (fail-fast rather than silently emitting a non-accessible PDF).
  #
  # Available? returns false when Drive credentials cannot be resolved, so
  # the registry filters :gdoc_pdf out of `.available` and records requesting
  # it fail fast rather than silently downgrading.
  #
  class Renderer < ::Exporters::Pdf::Renderers::Base
    def self.identifier = :gdoc_pdf

    def self.available?
      Exporter.credentials_present?
    end

    def call(_html, options:)
      source = options.source
      if source.nil?
        raise ::Exporters::Pdf::RendererRegistry::RenderError,
              "gdoc_pdf renderer requires options.source (the document/material " \
              "presenter). It is normally selected through Exporters::Pdf::Base, " \
              "which threads the record; direct invocation without a source is " \
              "not supported."
      end

      Exporter.new(source, options).to_pdf
    rescue Exporter::ExportError => e
      raise ::Exporters::Pdf::RendererRegistry::RenderError, "Gdoc PDF export failed: #{e.message}"
    end
  end
end
