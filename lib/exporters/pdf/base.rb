# frozen_string_literal: true

module Exporters
  module Pdf
    class Base < Exporters::Base
      def export
        Grover.new(pdf_content, **pdf_params).to_pdf
      end

      def pdf_content
        render_template template_path("show"), layout: "pdf"
      end

      protected

      private

      def pdf_custom_params
        @document.config.slice(:margin, :dpi)
      end

      def pdf_params
        {
          format: "Letter",
          landscape: (@document.orientation == "Landscape"),
          print_background: true,
          prefer_css_page_size: false,
          display_header_footer: true,
          footer_template: render_template(base_path("_footer"), layout: "pdf_plain")
        }.merge(pdf_custom_params)
      end
    end
  end
end
