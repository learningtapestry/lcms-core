# frozen_string_literal: true

module DocTemplate
  module Tags
    #
    # `[slide: id, slide-number, size]` shows a clickable thumbnail of one
    # slide of a Google Slides deck. `id` is a row of the URL spreadsheet
    # (Link) holding the deck's link; the thumbnail comes from
    # SlideThumbnailService and links to that slide. `size` is a percentage of
    # the page or, inside a table, of the cell width; it defaults to 50.
    #
    # The thumbnail is left-aligned on its own lines, with no text beside it.
    # When no thumbnail can be produced (unknown id, no such slide, the Slides
    # API failing) a solid red placeholder of the same size takes its place and
    # the import reports a warning.
    #
    class SlideTag < BaseTag
      include BlockPlacement

      TAG_NAME = "slide"
      TEMPLATES = { default: "slide.html.erb",
                    gdoc: "gdoc/slide.html.erb" }.freeze

      DEFAULT_SIZE = 50
      # A 16:9 solid red PNG, embedded so it needs no fetch in either export.
      PLACEHOLDER_SRC = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAJCAMAAAAM9FwAAAAAA1BMVEX/AAAZ4gk3AAAA" \
                        "DElEQVQI12NgGKQAAACZAAGVGD0UAAAAAElFTkSuQmCC"

      def parse(node, opts = {})
        @opts = opts
        identifier, slide_number, size = parse_args(opts[:value])
        link = ::Link.find_by_identifier(identifier)
        thumbnail = thumbnail_for(link, identifier, slide_number)

        @content = parse_template(
          {
            image_src: thumbnail&.image_url || PLACEHOLDER_SRC,
            slide_url: thumbnail&.slide_url,
            alt: alt_text(link, identifier, slide_number),
            size:
          },
          template_name(opts)
        )
        place_block(node)
        self
      end

      private

      # "id, 3, 80" => ["id", 3, 80]. Size defaults to 50 and is clamped to
      # 1..100; a missing slide number is nil.
      def parse_args(value)
        identifier, slide_number, size = value.to_s.split(",", 3).map(&:strip)
        slide_number = slide_number.to_s[/\d+/]&.to_i
        size = size.to_s[/\d+/]
        [identifier.to_s, slide_number, size ? size.to_i.clamp(1, 100) : DEFAULT_SIZE]
      end

      # The thumbnail, or nil after recording why there is none.
      def thumbnail_for(link, identifier, slide_number)
        error =
          if link.nil? then "unknown slide deck id '#{identifier}'"
          elsif slide_number.to_i < 1 then "no slide number"
          end
        error ||= (result = fetch(link.url, slide_number)).is_a?(String) ? result : nil
        return result unless error

        @errors << "Slide thumbnail for [slide: #{identifier}, #{slide_number}] is shown as a red placeholder: #{error}"
        nil
      end

      def fetch(deck_url, slide_number)
        memo = (Current.slide_thumbnails ||= {})
        memo[[deck_url, slide_number]] ||=
          begin
            SlideThumbnailService.call(deck_url, slide_number)
          rescue SlideThumbnailService::Error => e
            e.message
          end
      end

      def alt_text(link, identifier, slide_number)
        deck = link&.text.presence || identifier
        I18n.t("slide.alt", number: slide_number, deck:)
      end
    end
  end

  Template.register_tag(Tags::SlideTag::TAG_NAME, Tags::SlideTag)
end
