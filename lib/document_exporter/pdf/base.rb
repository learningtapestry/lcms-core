# frozen_string_literal: true

module DocumentExporter
  module Pdf
    class Base < DocumentExporter::Base
      def self.s3_folder
        @s3_folder ||= ENV.fetch("SWAP_DOCS", "documents")
      end

      def export
        Grover.new(pdf_content, **pdf_params).to_pdf
      end

      def pdf_content
        render_template template_path("show"), layout: "pdf"
      end

      protected

      def combine_pdf_for(pdf, material_ids)
        material_ids.each do |id|
          next unless (url = @document.links["materials"]&.dig(id.to_s, "url"))

          pdf << CombinePDF.parse(Net::HTTP.get(URI.parse(url)))
        end
        pdf
      end

      private

      TEMPLATE_EXTS = %w(erb html.erb).freeze
      private_constant :TEMPLATE_EXTS

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
