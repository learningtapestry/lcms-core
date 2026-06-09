# frozen_string_literal: true

# Register PDF renderer backends at boot.
#
# Default backends ship in core. Plugin backends register themselves
# in their own setup! hooks (loaded later via PluginSystem.load_all).
#
# Renderer-specific configuration (e.g. Grover's Puppeteer settings)
# stays in its own initializer (config/initializers/grover.rb).
#
# `to_prepare` (not `after_initialize`) so registration survives Zeitwerk
# code reloads in dev: when lib/exporters/pdf/renderer_registry.rb reloads,
# the module's @store is wiped, and `to_prepare` re-registers backends on
# the next request. Runs once in production.
Rails.application.config.to_prepare do
  Exporters::Pdf::RendererRegistry.register(Exporters::Pdf::Renderers::Grover)
end
