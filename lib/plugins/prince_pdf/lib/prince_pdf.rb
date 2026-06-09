# frozen_string_literal: true

# PrincePdf — accessible PDF rendering via the PrinceXML command-line tool.
#
# Plugs into Exporters::Pdf::RendererRegistry as `:prince`. Used when a
# document or job opts into accessibility (PDF/UA-1) output, which the
# default Grover/Chromium renderer cannot produce. See ADR-0001 §4.
#
# Runtime requirements:
#   - PrinceXML binary on PATH (or PRINCE_EXECUTABLE_PATH set)
#   - Optional: PRINCE_LICENSE_PATH for unwatermarked output
#
# See README.md for installation, licensing, and Docker integration.
#
module PrincePdf
  class << self
    def setup!
      ::Exporters::Pdf::RendererRegistry.register(Renderer)
      PluginSystem.logger.info \
        "[PrincePdf] :prince renderer registered (available=#{Renderer.available?})"
    end
  end
end
