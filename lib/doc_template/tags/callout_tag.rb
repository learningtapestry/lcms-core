# frozen_string_literal: true

module DocTemplate
  module Tags
    class CalloutTag < TableTag
      TAG_NAME = "callout"
      # Legacy 3-row shape: tr[1] marker, tr[2] header, tr[3] content.
      TEMPLATES = {
        default: "callout.html.erb",
        gdoc: "gdoc/callout.html.erb"
      }.freeze
      # New 1-row 2-col shape: col[1] icon+label (with marker), col[2] content.
      INLINE_TEMPLATES = {
        default: "callout_inline.html.erb",
        gdoc: "gdoc/callout_inline.html.erb"
      }.freeze

      def parse_table(table)
        inline = inline_shape?(table)
        header, content = fetch_content(table, inline:)
        params = {
          content:,
          header:,
          subject: @opts[:metadata].subject,
          # Tells the inline template whether the author supplied an
          # icon/label as authored HTML (1-row 2-col shape) or just a
          # plain category label (3-row shapes — renderer adds a default
          # decoration).
          authored_label: inline
        }
        # All callouts render with the inline horizontal visual per the
        # LCMS Core spec, regardless of how the author structured the
        # source table.
        new_content = parse_template params, inline_template_name

        @opts[:parent_node] = new_content
        parsed_content = parse_nested new_content, @opts

        # Place placeholder where it should be
        before_tag(previous_non_empty(table) || table)

        # returns the generated content to be stored as part
        @content = parsed_content
        table.remove
      end

      private

      def inline_shape?(node)
        node.xpath(".//tr").size == 1
      end

      def fetch_content(node, inline:)
        if inline
          cells = node.xpath(".//tr[1]/td")
          [
            strip_tag_marker(cells[0]&.inner_html.to_s),
            cells[1]&.inner_html.to_s
          ]
        else
          # Legacy 3-row shape supports two authoring variants:
          #   (a) 3-row 1-col: tr[2]/td=header, tr[3]/td=content
          #   (b) 3-row 2-col labeled: tr[2] = "type" | <subject>,
          #                            tr[3] = "text" | <body>
          # Prefer td[2] (value column) when present; fall back to td[1].
          [
            value_cell_content(node, 2),
            value_cell_inner_html(node, 3)
          ]
        end
      end

      def value_cell_content(node, row_index)
        row = node.at_xpath(".//tr[#{row_index}]")
        return "" unless row

        value = row.at_xpath("./td[2]").try(:content).to_s.squish
        value.presence || row.at_xpath("./td[1]").try(:content).to_s
      end

      def value_cell_inner_html(node, row_index)
        row = node.at_xpath(".//tr[#{row_index}]")
        return "" unless row

        value = row.at_xpath("./td[2]").try(:inner_html).to_s
        value.strip.presence || row.at_xpath("./td[1]").try(:inner_html).to_s
      end

      def strip_tag_marker(html)
        html.gsub(/\[\s*#{Regexp.escape(self.class::TAG_NAME)}[^\]]*\]/i, "")
      end

      def inline_template_name
        context = @opts.fetch(:context_type, :default).to_s
        INLINE_TEMPLATES[context.to_sym]
      end

      def previous_non_empty(node)
        while (node = node.previous_sibling)
          break unless node.content.squish.blank?
        end
        node
      end
    end

    Template.register_tag(Tags::CalloutTag::TAG_NAME, CalloutTag)
  end
end
