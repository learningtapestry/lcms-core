# frozen_string_literal: true

module Exporters
  module Pdf
    # Generates a PDF by first creating a Google Doc (via the Gdoc exporter for the
    # presenter type) and then asking Drive to export that doc as application/pdf.
    #
    # Trades Grover/Chromium rendering for visual parity with the corresponding Gdoc,
    # at the cost of always creating a Drive file (the doc is post-processed by
    # Google::ScriptService for header/footer before export).
    class ViaGdoc
      GDOC_EXPORTERS = {
        "MaterialPresenter" => ::Exporters::Gdoc::Material,
        "DocumentPresenter" => ::Exporters::Gdoc::Document
      }.freeze

      def initialize(presenter, options = {})
        @presenter = presenter
        @options = options
      end

      def export
        gdoc = build_gdoc_exporter.export
        io = StringIO.new.binmode
        gdoc.drive_service.service.export_file(gdoc.id, "application/pdf", download_dest: io)
        io.string
      end

      private

      def build_gdoc_exporter
        klass = GDOC_EXPORTERS[@presenter.class.name] or
          raise ArgumentError, "Unsupported presenter for Pdf::ViaGdoc: #{@presenter.class.name}"
        klass.new(@presenter, @options)
      end
    end
  end
end
