# frozen_string_literal: true

# Register PDF renderer backends at boot.
#
# Default backends ship in core. Plugin backends register themselves
# in their own setup! hooks (loaded later via PluginSystem.load_all).
#
# Renderer-specific configuration (e.g. Grover's Puppeteer settings)
# stays in its own initializer (config/initializers/grover.rb).
#
Rails.application.config.after_initialize do
  Exporters::Pdf::RendererRegistry.register(Exporters::Pdf::Renderers::Grover)
end
