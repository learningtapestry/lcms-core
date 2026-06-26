# frozen_string_literal: true

module Exporters
  module Pdf
    #
    # Base PDF exporter. Subclasses (Pdf::Document, Pdf::Material) supply
    # only `base_path` for template resolution.
    #
    # Renderer selection follows a two-tier model:
    #
    #   Tier 1 — admin-facing (the only user-visible surface):
    #     The project's default renderer, chosen by an operator in
    #     settings. Currently held in the DEFAULT_PDF_RENDERER env var
    #     and read by RendererRegistry.default; will move to a DB-backed
    #     setting in the pdf.yml→DB follow-up scope.
    #
    #   Tier 2 — programmatic (extension points for plugins):
    #     Bespoke per-project plugins that own complex bundle assembly
    #     (e.g. mixing renderers across pieces of a bundle, where PDF/UA
    #     tags don't survive concatenation so bundles must be rendered
    #     in one Prince pass over composed HTML) route specific records
    #     or pieces to specific renderers. Two seams exist for plugin
    #     code, neither surfaced as core-controller params or admin UI:
    #       (a) per-call:   options[:renderer], options[:accessibility]
    #       (b) per-record: @document.pdf_renderer / @document.accessibility
    #                       — core models do not define these methods;
    #                       a plugin opts in by extending Document/Material
    #                       with accessors that read from metadata jsonb.
    #       (c) record handle: build_render_options threads the presenter into
    #                       RenderOptions#source so a renderer that needs the
    #                       record itself (not just rendered HTML) can reach it
    #                       — e.g. the gdoc_pdf plugin, which exports the
    #                       record's Google Doc to PDF rather than rendering HTML.
    #
    # Resolution chain (preserved in #renderer_name / #accessibility_level):
    #   per-call option -> per-record method -> project default
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
        layout = layout_name_for(renderer)
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
          footer_html: render_template(base_path("_footer"), layout: "pdf_plain"),
          source: @document
        )
      end

      def layout_name_for(renderer)
        renderer_class = renderer.is_a?(Class) ? renderer : renderer.class
        return renderer_class.layout_name if renderer_class.respond_to?(:layout_name)

        Renderers::Base::DEFAULT_LAYOUT
      end
    end
  end
end
