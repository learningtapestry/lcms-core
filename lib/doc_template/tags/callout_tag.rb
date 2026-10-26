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
        warn_unknown_type(type) if type && callout.nil?
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
          # Absent outside a document (a callout in a metadata field rendered
          # by DocTemplate::InlineTags has no document metadata).
          subject: @opts[:metadata].try(:subject),
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

        # returns the generated content to be stored as part
        @content = parsed_content

        # The box appears in line, exactly where the author put the table:
        # as a part placeholder, or the box itself when rendered inline (a
        # callout in a metadata field). It used to go before the preceding
        # paragraph, a leftover from callouts that floated beside that
        # paragraph as a sidebar.
        replace_tag(table)
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
          # Title is plain text; BaseTag#parse_template escapes it at render
          # time (it reaches both element content and an `alt=""` attribute).
          hash[key] = { title: row[:title].to_s, image: row[:image] } if key.present?
        end
      end

      # Import warning for a type the client has not configured (admin
      # Settings > Documents > Callout Types). The callout still renders, with
      # the authored type as its label.
      def warn_unknown_type(type)
        known = configured_callout_types.keys
        @errors << "Unknown callout type '#{type}' (configured types: #{known.join(', ').presence || 'none'})"
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

      # The callout type keyword, normalized to a lowercase key: the argument
      # of a `[callout: <type>]` marker, or else the value of a `type` row
      # (the spec's `[callout]` / `type | tip` / `text | …` shape). nil when
      # neither is authored.
      def callout_type(node)
        marker = node.inner_html[/\[\s*#{Regexp.escape(self.class::TAG_NAME)}\s*:?\s*([^\]]*)\]/i, 1]
        (marker.presence || labeled_cell(node, "type")&.text).to_s.strip.downcase.presence
      end

      # Value cell (td[2]) of the row whose first cell reads `label`.
      def labeled_cell(node, label)
        row = direct_rows(node).find { it.at_xpath("./td[1]")&.text.to_s.squish.casecmp?(label) }
        row&.at_xpath("./td[2]")
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
          # A `text` row is found by its label, so the body survives the two
          # labeled rows being authored in either order.
          [
            labeled_cell(node, "type")&.content.to_s.squish.presence || value_cell_content(node, 2),
            labeled_cell(node, "text")&.inner_html.to_s.strip.presence || value_cell_inner_html(node, 3)
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
    end

    Template.register_tag(Tags::CalloutTag::TAG_NAME, CalloutTag)
  end
end
