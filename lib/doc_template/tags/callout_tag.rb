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
        # The keyword in `[callout: <type>]` selects the canonical type; nil
        # when absent or not a client-configured callout type (see
        # #configured_callout_types).
        type = callout_type(table)
        callout = configured_callout_types[type]
        title = callout&.fetch(:title, nil)
        params = {
          content:,
          header:,
          # Canonical type keyword and display title, present only for a
          # recognized `[callout: <type>]`. The template renders the title
          # (and a per-type icon) instead of the authored label.
          type: (callout ? type : nil),
          title:,
          # Configured icon URL (or a gdoc-inlined data URI — see
          # #callout_icon_url), nil when unconfigured/no upload: the
          # template falls back to a plain "+" in that case.
          image: callout_icon_url(callout&.fetch(:image, nil)),
          subject: @opts[:metadata].subject,
          # Tells the inline template whether the author supplied an
          # icon/label as authored HTML (1-row 2-col shape) or just a
          # plain category label (3-row shapes — renderer adds a default
          # decoration). A canonical title supersedes the authored label,
          # so this is only honored for untyped callouts.
          authored_label: inline && title.nil?
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

      # Client-configurable callout type => {title:, image:} map (see admin
      # Settings > Documents > Callout Types, DocTemplate::Tags::CalloutTag's
      # counterpart in FlatGroup). Ships with 4 default types (see
      # Settings::DEFAULTS[:documents][:callout_types]) that resolve even
      # before an operator ever opens the settings screen. Row hashes come
      # back deep_symbolize_keys'd by Settings.merge_with_defaults, but are
      # normalized defensively here in case a caller ever stubs Settings with
      # string-keyed rows. Type is folded to a lowercase key to match
      # #callout_type's marker parsing.
      def configured_callout_types
        rows = Settings.get(:documents, include_defaults: true)&.dig(:callout_types) || []
        rows.each_with_object({}) do |row, hash|
          row = row.to_h.symbolize_keys
          key = row[:type].to_s.strip.downcase
          hash[key] = { title: row[:title].to_s, image: row[:image] } if key.present?
        end
      end

      # Resolves the icon URL for the current output context. Gdoc output is
      # routed through Drive at import time, which drops external image
      # references, so the icon is inlined as a data URI there — mirrors
      # ContentPresenter#brandmark_url. PDF/default output (Grover/Chromium)
      # fetches a plain URL fine.
      def callout_icon_url(raw_url)
        return nil if raw_url.blank?
        return raw_url unless @opts.fetch(:context_type, :default).to_s == "gdoc"

        AssetHelper.inline_data_uri(raw_url, cache: ViewHelper::ENABLE_BASE64_CACHING) || raw_url
      end

      def inline_shape?(node)
        direct_rows(node).size == 1
      end

      # Rows that belong directly to this callout table, excluding rows of any
      # nested table in a body cell. Using `.//tr` here would count nested rows
      # too and misclassify a 1-row/2-col callout whose body cell contains a
      # table as the legacy 3-row shape.
      def direct_rows(node)
        node.xpath("./tr | ./tbody/tr | ./thead/tr | ./tfoot/tr")
      end

      # Extracts the keyword from the `[callout: <type>]` marker anywhere in
      # the table, normalized to a lowercase key. nil when the marker has no
      # argument (`[callout]`).
      def callout_type(node)
        marker = node.inner_html[/\[\s*#{Regexp.escape(self.class::TAG_NAME)}\s*:?\s*([^\]]*)\]/i, 1]
        marker.to_s.strip.downcase.presence
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

      # Template for the inline visual every callout now renders with.
      #
      # Keeps BaseTag#template_name's two behaviours, which a bare
      # INLINE_TEMPLATES lookup dropped: a per-context override configured in
      # config/lcms.yml (`tags.callout.templates.<context>`) still wins, and an
      # unmapped context falls back to :default instead of handing nil to
      # File.read — which raised TypeError and aborted the whole render.
      def inline_template_name
        context = @opts.fetch(:context_type, :default).to_s
        override = ::DocTemplate::Tags.config.dig(TAG_NAME, "templates", context)
        override.presence || INLINE_TEMPLATES[context.to_sym] || INLINE_TEMPLATES[:default]
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
