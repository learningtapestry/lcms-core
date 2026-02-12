# frozen_string_literal: true

require "doc_template"

module DocTemplate
  module Tags
    class LatexTag < BaseTag
      S3_FOLDER = "documents-latex-equations"
      SPACE_RE = /[[:space:]]/
      TAG_NAME = "latex"

      def parse(node, opts = {})
        @parent_node = opts[:parent_node]
        @value = opts[:value].gsub(SPACE_RE, "")
        expression =
          begin
            if opts[:context_type]&.to_sym == :gdoc
              generate_image do |png|
                key = "#{S3_FOLDER}/#{SecureRandom.hex(20)}.png"
                url = S3Service.upload(key, png, content_type: "image/png")
                %(<img class="o-ld-latex" src="#{url}">)
              end
            else
              EmbedEquations.tex_to_svg @value, preserve_color: preserve_color?
            end
          rescue StandardError => e
            raise if Rails.env.test?

            msg = "Error converting Latex expression: #{@value}"
            Rails.logger.warn "#{e.message} => #{msg}"
            msg
          end

        node.inner_html = node.inner_html.sub DocTemplate::FULL_TAG, expression
        @result = node
        self
      end

      def tag_data
        { latex: value }
      end

      private

      attr_reader :parent_node, :value

      def custom_color
        return if parent_node.nil?

        config = Tags.config[self.class::TAG_NAME.downcase]
        config["color"]
      end

      def generate_image
        svg_path =
          Tempfile.open(%w(tex-eq .svg)) do |svg|
            svg.write EmbedEquations.tex_to_svg(value, custom_color:)
            svg.path
          end

        png = Tempfile.new %w(tex-eq .png)
        begin
          system("svgexport", svg_path.to_s, png.path.to_s)
          yield File.read(png.path.to_s)
        ensure
          png.close true
        end
      end

      def preserve_color?
        return false if parent_node.nil?

        html = Nokogiri::HTML.fragment parent_node
        html.at_css("div")["class"].to_s.downcase.include? "o-ld-callout"
      end
    end
  end

  Template.register_tag(Tags::LatexTag::TAG_NAME, Tags::LatexTag)
end
