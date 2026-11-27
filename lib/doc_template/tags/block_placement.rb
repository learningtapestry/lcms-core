# frozen_string_literal: true

module DocTemplate
  module Tags
    #
    # Places a tag's rendered content as a block of its own, where the tag
    # sits. Shared by ImageTag (centered images) and SlideTag.
    #
    module BlockPlacement
      private

      # Inside a paragraph, the paragraph is split around the tag so the
      # content stands between its two halves (block content cannot sit
      # inside a <p>). Inside any other element (a list item, a table cell)
      # block content is valid, so the tag is replaced in place.
      def place_block(node)
        return replace_tag_inline(node) unless node.name == "p"

        text_nodes = node.xpath(".//text()").to_a
        match = DocTemplate::FULL_TAG.match(text_nodes.map(&:content).join)
        return replace_tag(node) unless match

        marker = "#{placeholder_id}-split"
        splice_tag(text_nodes, match, marker)

        before = cut(node.dup, marker, keep: :before)
        after = cut(node.dup, marker, keep: :after)
        middle = @opts[:explicit_render] ? content.to_s : placeholder
        node.replace(Nokogiri::HTML.fragment([before, middle, after].compact.join))
        @result = nil
      end

      # Keeps the part of `root` before (or after) the marker, removing the
      # marker and everything on the other side of it at every nesting level.
      # Line breaks left at the cut are dropped. Returns nil when nothing
      # visible is left.
      def cut(root, marker, keep:)
        text = root.xpath(".//text()").find { it.content.include?(marker) }
        head, tail = text.content.split(marker, 2)
        text.content = keep == :before ? head.to_s : tail.to_s

        sibling = keep == :before ? :next_sibling : :previous_sibling
        current = text
        until current == root
          while (other = current.public_send(sibling))
            other.remove
          end
          current = current.parent
        end

        trim_breaks(root, keep == :before ? :last : :first)
        visible?(root) ? root.to_html : nil
      end

      # Drops line breaks, blank text and emptied elements (a <span> whose
      # text went to the other half) from one edge of `root`.
      def trim_breaks(root, edge)
        loop do
          leaf = root.xpath(".//node()[not(node())]").public_send(edge)
          break unless leaf && leaf.name != "img" && leaf.content.gsub(BaseTag::UNICODE_SPACES_RE, "").strip.empty?

          leaf.remove
        end
      end

      def visible?(root)
        root.text.gsub(BaseTag::UNICODE_SPACES_RE, "").strip.present? || root.at_css("img").present?
      end
    end
  end
end
