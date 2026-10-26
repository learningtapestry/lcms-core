# frozen_string_literal: true

module Exporters
  module Pdf
    #
    # Unit document PDF (the Teacher Edition front matter: cover, copyright,
    # ...). Expects a UnitPresenter.
    #
    # Every page after the cover carries the bundled-document running header
    # and footer (app/views/bundles/pdf). Chromium applies its header/footer
    # templates to every page and has no first-page exception, so the PDF is
    # rendered twice and spliced:
    #
    #   1. pages: :after_cover — a blank placeholder page 1, then the rest of
    #      the document with the running header/footer. Page numbers count the
    #      placeholder, so the copyright page is numbered 2.
    #   2. pages: :cover — the cover alone, without header/footer.
    #
    # The result is the cover page followed by pages 2..N of the first pass.
    # Splicing is skipped for tagged/PDF-UA output, whose structure tree does
    # not survive concatenation (see Exporters::Pdf::Base); renderers that can
    # produce those (Prince) ignore the HTML header/footer templates anyway.
    # It is also skipped for a renderer that does not render the HTML at all
    # (:gdoc_pdf exports the bundle Google Doc, whose first page the Apps
    # Script already keeps free of the running header/footer).
    #
    class Unit < Pdf::Base
      # Spec page margins are 0.5in. Chromium draws the running header/footer
      # inside the page margin, so the top and bottom margins also hold them;
      # the header/footer templates pad themselves 0.5in from the page edge.
      BUNDLE_MARGIN = { top: "1.2in", right: "0.5in", bottom: "1.15in", left: "0.5in" }.freeze

      def export
        return super unless accessibility_level == :none && renders_html?

        cover = with_pages(:cover) { super }
        rest = with_pages(:after_cover) { super }
        splice(cover, rest)
      end

      private

      def base_path(name)
        File.join("units", "pdf", name)
      end

      def renders_html?
        renderer = RendererRegistry.fetch(renderer_name)
        renderer_class = renderer.is_a?(Class) ? renderer : renderer.class
        !renderer_class.respond_to?(:renders_html?) || renderer_class.renders_html?
      end

      def build_render_options
        render_options = @document.render_options.with(accessibility: accessibility_level, source: @document)
        return render_options if @options[:pages] == :cover

        render_options.with(
          margin: BUNDLE_MARGIN,
          header_html: render_template(File.join("bundles", "pdf", "_header"), layout: "pdf_plain"),
          footer_html: render_template(File.join("bundles", "pdf", "_footer"), layout: "pdf_plain")
        )
      end

      def splice(cover_pdf, rest_pdf)
        result = CombinePDF.parse(cover_pdf)
        CombinePDF.parse(rest_pdf).pages.drop(1).each { result << it }
        result.to_pdf
      end

      # Renders with options[:pages] set (read by units/pdf/show.html.erb and
      # #build_render_options), restoring the caller's options afterwards.
      def with_pages(pages)
        original = @options
        @options = @options.merge(pages:)
        yield
      ensure
        @options = original
      end
    end
  end
end
