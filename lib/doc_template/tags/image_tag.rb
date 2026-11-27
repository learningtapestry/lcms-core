# frozen_string_literal: true

module DocTemplate
  module Tags
    #
    # `[image: image_id, size]` places an image from the image spreadsheet
    # (Image, imported by ImagesImportService). `size` is a percentage of the
    # page or, inside a table, of the cell width; it defaults to 100.
    #
    # - size > 50: the image is centered on its own lines, with no text beside
    #   it, followed by the sheet's caption and/or credit. A tag sitting inside
    #   a paragraph splits it: text before the tag stays above the image, text
    #   after it continues below.
    # - size <= 50: the image is left-aligned where the tag sits and the text
    #   that follows wraps beside it; no caption or credit.
    #
    # The sheet's alt text is used for every image. Unknown ids render an error
    # badge, like unknown material tags.
    #
    class ImageTag < BaseTag
      include BlockPlacement

      TAG_NAME = "image"
      TEMPLATES = { default: "image.html.erb",
                    gdoc: "gdoc/image.html.erb" }.freeze

      DEFAULT_SIZE = 100
      WRAP_MAX_SIZE = 50

      def parse(node, opts = {})
        @opts = opts
        identifier, size = parse_args(opts[:value])
        image = ::Image.find_by_identifier(identifier)

        unless image
          @content = %(<span class="badge text-bg-danger">Unknown image: #{ERB::Util.html_escape(identifier)}</span>)
          replace_tag_inline(node)
          return self
        end

        wrap = size <= WRAP_MAX_SIZE
        @content = parse_template(
          {
            image_src: image.file_url,
            alt: image.alt_text.to_s,
            size:,
            wrap:,
            caption: (wrap ? "" : image.caption.to_s),
            credit: (wrap ? "" : image.credit.to_s)
          },
          template_name(opts)
        )
        wrap ? replace_tag_inline(node) : place_block(node)
        self
      end

      private

      # "id, 80" => ["id", 80]. A missing or unreadable size means full width;
      # sizes are clamped to 1..100.
      def parse_args(value)
        identifier, size = value.to_s.split(",", 2).map(&:strip)
        size = size.to_s[/\d+/]
        [identifier.to_s, size ? size.to_i.clamp(1, 100) : DEFAULT_SIZE]
      end
    end
  end

  Template.register_tag(Tags::ImageTag::TAG_NAME, Tags::ImageTag)
end
