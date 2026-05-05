# frozen_string_literal: true

module Exporters
  module Pdf
    #
    # Base PDF exporter. Subclasses (Pdf::Document, Pdf::Material) supply
    # only `base_path` for template resolution. Renderer selection happens
    # at runtime via Exporters::Pdf::RendererRegistry; the default backend
    # is :grover (registered in config/initializers/pdf_renderers.rb).
    #
    # Resolution order for the renderer:
    #   options[:renderer] -> @document.pdf_renderer -> RendererRegistry.default
    #
    # Resolution order for accessibility:
    #   options[:accessible_pdf] == true -> :pdf_ua  (shorthand)
    #   options[:accessibility]                       (explicit)
    #   @document.accessibility                       (per-record)
    #   :none                                         (default)
    #
    # The registry rejects unsupported (renderer, accessibility) combinations
    # before any HTML is rendered (e.g. :grover + :pdf_ua raises
    # UnsupportedCapability).
    #
    class Base < Exporters::Base
      def export
        @render_options = build_render_options
        renderer = RendererRegistry.fetch_for(
          identifier: renderer_name,
          accessibility: @render_options.accessibility
        )
        layout = renderer.class.layout_name
        html = render_template(template_path("show"), layout: layout)
        renderer.call(html, options: @render_options)
      end

      private

      def renderer_name
        @options[:renderer]&.to_sym ||
          (@document.respond_to?(:pdf_renderer) && @document.pdf_renderer&.to_sym) ||
          RendererRegistry.default
      end

      def accessibility_level
        return :pdf_ua if @options[:accessible_pdf] == true

        @options[:accessibility]&.to_sym ||
          (@document.respond_to?(:accessibility) && @document.accessibility&.to_sym) ||
          :none
      end

      def build_render_options
        @document.render_options.with(
          accessibility: accessibility_level,
          footer_html: render_template(base_path("_footer"), layout: "pdf_plain")
        )
      end
    end
  end
end
