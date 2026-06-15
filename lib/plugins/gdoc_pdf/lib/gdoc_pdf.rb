# frozen_string_literal: true

# GdocPdf — PDF rendering via Google Doc export.
#
# Plugs into Exporters::Pdf::RendererRegistry as `:gdoc_pdf`. Instead of
# rendering HTML through a print engine, this renderer exports the record's
# *actual* generated Google Doc to PDF via the Drive `files.export` endpoint.
# The result is byte-for-byte identical in styling to the published Google
# Doc — same Apps-Script-applied headers/footers and Docs layout — which the
# HTML-based :grover and :prince renderers cannot guarantee. See ADR-0001.
#
# Because it needs the record (not just rendered HTML), it reads the
# presenter from RenderOptions#source, threaded in by Exporters::Pdf::Base.
#
# Runtime requirements:
#   - The same Google Drive service-account credentials used by the Gdoc
#     pipeline (file-based credentials resolved via Lt::Google::Api::Auth::Cli)
#   - The Drive export size ceiling is 10 MB per file
#
# See README.md for configuration and behavior details.
#
module GdocPdf
  class << self
    def setup!
      ::Exporters::Pdf::RendererRegistry.register(Renderer)
      PluginSystem.logger.info \
        "[GdocPdf] :gdoc_pdf renderer registered (available=#{Renderer.available?})"
    end
  end
end
