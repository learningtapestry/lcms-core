# frozen_string_literal: true

module DocTemplate
  module Tags
    class ImageTag < TableTag
      TAG_NAME = "image"
      TEMPLATES = { default: "image.html.erb",
                    gdoc: "gdoc/image.html.erb" }.freeze

      # Authored as `[image: <id> align=<a> size=<s>]`. Alignment drives text
      # wrapping (only `left`/`right` float and wrap); size maps to a width
      # preset in the stylesheet. Unrecognized values fall back to defaults.
      ALIGNMENTS = %w(center left right).freeze
      SIZES = %w(small medium large).freeze
      DEFAULT_ALIGNMENT = "center"
      DEFAULT_SIZE = "large"

      def parse_table(table)
        id, align, size = parse_args(@opts[:value])
        # Per spec, captions and credits appear only on centered images;
        # left/right images wrap surrounding text and show neither.
        show_meta = align == "center"
        caption = cell_text(table, 2)
        params = {
          image_src: image_src(id),
          align:,
          size:,
          # The authored caption doubles as alt text and is emitted for EVERY
          # alignment, unlike the visible caption below: a left/right image is
          # still an image a screen reader has to describe, and this is the only
          # description the author gives us. Matters for the prince_pdf plugin,
          # which targets PDF/UA-1.
          alt: caption,
          caption: (show_meta ? caption : ""),
          credit: (show_meta ? cell_text(table, 3) : ""),
          subject: @opts[:metadata].try(:[], "subject")
        }
        @content = parse_template(params, template_name(@opts))
        replace_tag table
      end

      private

      # Splits the tag value "<id> align=<a> size=<s>" into [id, align, size],
      # applying defaults and ignoring unrecognized keys/values. Only `align=`
      # and `size=` tokens are treated as options; every other token is part of
      # the id and rejoined with spaces, so a legacy id that contains spaces
      # (e.g. "[image: some id]") still resolves to the original filename rather
      # than being truncated at the first space.
      def parse_args(value)
        opts = {}
        id_tokens = value.to_s.strip.split(/\s+/).reject do |token|
          key, val = token.split("=", 2)
          next false if val.nil?

          key = key.downcase
          next false unless %w(align size).include?(key)

          opts[key] = val.downcase
          true
        end
        id = id_tokens.join(" ")
        align = ALIGNMENTS.include?(opts["align"]) ? opts["align"] : DEFAULT_ALIGNMENT
        size = SIZES.include?(opts["size"]) ? opts["size"] : DEFAULT_SIZE
        [id, align, size]
      end

      # Author-supplied TEXT from the tag table (`.text`, so entities are already
      # decoded and a caption may legitimately contain a quote or an angle
      # bracket). Deliberately not escaped here: BaseTag#parse_template escapes
      # every `<%= %>` by default, so escaping again would be a second, silent
      # authority on the same value.
      def cell_text(table, row)
        table.at_xpath(".//tr[#{row}]/td").try(:text).to_s
      end

      def image_src(id)
        filename = "#{id}.jpg"
        grade = @opts[:metadata]["grade"]
        unit = @opts[:metadata]["unit"]
        "https://unbounded-uploads-development.s3.amazonaws.com/ela-images/G#{grade}/#{unit}/#{filename}"
      end
    end
  end

  Template.register_tag(Tags::ImageTag::TAG_NAME, Tags::ImageTag)
end
