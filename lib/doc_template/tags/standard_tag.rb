# frozen_string_literal: true

module DocTemplate
  module Tags
    class StandardTag < BaseTag
      include ERB::Util

      # A standard code written as a tag, e.g. [RL.2.4], [ELA.RL.2.4], [8.EE.1],
      # [HSA-CED.A.2] or [HS-ESS2-3]: letters and digits in parts joined by
      # dots or hyphens, with at least one digit and one letter. That keeps
      # other tags (all digit-free) and plain numbers like [1.5] out.
      CODE = /(?=[a-z0-9.-]*\d)(?=[a-z0-9.-]*[a-z])[a-z0-9]+(?:[.-][a-z0-9]+)+/i
      STANDARD_RE = /[^\[\]]*\[(#{CODE})\]/i
      TAG_NAME = /\A#{CODE}\z/i
      TAG_RE = /\[[^\]]*\]/
      TAG_SEPARATOR = "[separator]"
      TEMPLATES = { default: "standard.html.erb",
                    gdoc: "gdoc/standard.html.erb" }.freeze

      def parse(node, opts)
        @opts = opts
        @content = render_template node, opts
        loop do
          break unless STANDARD_RE =~ @content

          @content = render_template Nokogiri::HTML.fragment(@content), opts
        end

        # preserve `li` element
        if node.name == "li"
          @result = node.replace "<li class='#{node['class']}'>#{placeholder}</li>"
        else
          replace_tag node
        end

        self
      end

      private

      # Extracting content outside the tag
      # TODO: Extract to the parent class
      def fetch_data(source)
        @preserved_style = %r{<span (style=[^.>]*)>[^<]+</span>$}.match(source).try(:[], 1)
        {}.tap do |result| # steep:ignore
          data = source.squish
                   .sub(TAG_RE, TAG_SEPARATOR)
                   .split(TAG_SEPARATOR, 2)
                   .reject(&:blank?)
          break unless data

          result[:prepend] = data[0]
          result[:append] = data[1]
        end
      end

      def fetch_description(text)
        return unless (matches = STANDARD_RE.match text)

        Standard.find_by_code(matches[1], subject: @opts[:metadata].try(:[], "subject"))&.description
      end

      def render_template(node, opts)
        @data = fetch_data node.inner_html
        @standard_shortcut = TAG_RE.match(node.content).try(:[], 0).try(:gsub, /[\[\]]/, "")
        @description = fetch_description node.content

        template = File.read template_path(template_name(opts))
        ERB.new(template).result(binding).gsub(/\s{2,}</, "<")
      end
    end
  end

  Template.register_tag(Tags::StandardTag::TAG_NAME, Tags::StandardTag)
end
