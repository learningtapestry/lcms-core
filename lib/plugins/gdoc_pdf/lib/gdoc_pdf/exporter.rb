# frozen_string_literal: true

require "stringio"
require "google/apis/drive_v3"

module GdocPdf
  #
  # Resolves (or generates) the record's Google Doc and exports it to PDF.
  #
  # Source resolution:
  #   1. Reuse — if the record already has a Google Doc link in
  #      `links[content_type]["gdoc"]`, export that doc as-is. No staleness
  #      check: the PDF faithfully mirrors the published Google Doc.
  #   2. Generate (ephemeral) — otherwise run the full Gdoc pipeline
  #      (Exporters::Gdoc::Document / Material, including Google::ScriptService
  #      post-processing) to produce the doc, then export it. The generated
  #      doc is NOT written back into the record's `links` — generation is a
  #      side effect of this render, not a change to the gdoc lifecycle.
  #      (The Gdoc pipeline updates an existing same-named doc in place rather
  #      than creating duplicates, so repeated renders stay idempotent.)
  #
  # Export uses Drive `files.export` with mimeType application/pdf. Drive caps
  # exported files at 10 MB; larger documents raise ExportError.
  #
  class Exporter
    class ExportError < StandardError; end

    PDF_MIME = "application/pdf"
    GDOC_LINK_KEY = "gdoc"
    RATE_RETRIABLE_ERRORS = ::Exporters::Gdoc::Base::GOOGLE_API_RATE_RETRIABLE_ERRORS
    EXPORT_TRIES = ENV.fetch("GDOC_PDF_EXPORT_TRIES", 5).to_i
    EXPORT_BASE_INTERVAL = ENV.fetch("GDOC_PDF_EXPORT_BASE_INTERVAL", 5).to_i

    class << self
      # True when Google Drive credentials can be resolved. Used by the
      # renderer's `.available?` so the registry can filter :gdoc_pdf out
      # when credentials are absent. Non-raising by design.
      def credentials_present?
        ::Lt::Google::Api::Auth::Cli.new.credentials.present?
      rescue StandardError
        false
      end
    end

    # @param source [DocumentPresenter, MaterialPresenter] the record presenter
    #   threaded in via RenderOptions#source
    # @param render_options [Exporters::Pdf::RenderOptions, nil] the render
    #   options (currently unused by the export path; accepted for symmetry
    #   and future per-call overrides)
    def initialize(source, render_options = nil)
      @source = source
      @render_options = render_options
    end

    # @return [String] the exported PDF bytes
    def to_pdf
      export_to_pdf(resolve_file_id)
    rescue ::Google::Apis::Error => e
      raise ExportError, e.message
    end

    private

    attr_reader :source

    def resolve_file_id
      reuse_file_id || generate_file_id
    end

    # Step 1 — reuse an already-generated Google Doc, if one is linked.
    def reuse_file_id
      entry = source.links&.dig(source.content_type.to_s, GDOC_LINK_KEY)
      url = entry.is_a?(Hash) ? entry["url"] : entry
      extract_file_id(url)
    end

    # Step 2 — generate the Google Doc through the full Gdoc pipeline.
    def generate_file_id
      gdoc = gdoc_exporter_class.new(source, {}).export
      extract_file_id(gdoc.url)
    end

    def gdoc_exporter_class
      source.is_a?(MaterialPresenter) ? ::Exporters::Gdoc::Material : ::Exporters::Gdoc::Document
    end

    def export_to_pdf(file_id)
      raise ExportError, "no Google Doc available to export for #{source.class}" if file_id.blank?

      # A fresh StringIO per attempt: Drive's download streams bytes into the
      # supplied IO without truncating it, so reusing one buffer across retries
      # would append a second copy after a partial write and corrupt the PDF.
      Retriable.retriable(on: RATE_RETRIABLE_ERRORS, tries: EXPORT_TRIES, base_interval: EXPORT_BASE_INTERVAL) do
        io = StringIO.new.tap { |s| s.set_encoding(Encoding::BINARY) }
        drive.service.export_file(file_id, PDF_MIME, download_dest: io)
        io.string
      end
    end

    # Google Doc URLs are stored as `https://drive.google.com/open?id=<id>`
    # (see Exporters::Gdoc::Base.url_for). Delegate to the canonical inverse so
    # the URL schema lives in one place and the `/d/<id>` form is tolerated.
    def extract_file_id(url)
      ::Exporters::Gdoc::Base.file_id_from(url)
    end

    def drive
      @drive ||= ::Google::DriveService.build(source, {})
    end
  end
end
