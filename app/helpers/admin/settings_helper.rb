# frozen_string_literal: true

module Admin
  # View helpers for the admin Settings UI.
  module SettingsHelper
    # Memoized for the lifetime of the current request so partials inside the
    # `SETTINGS.each` loop don't re-probe backend availability per iteration
    # (Prince's `available?` shells out to `prince --version`; module-level
    # memoization handles repeat calls within a process, but a single helper
    # call per request keeps the contract explicit).
    def available_pdf_renderers
      @available_pdf_renderers ||= Exporters::Pdf::RendererRegistry.available
    end
  end
end
