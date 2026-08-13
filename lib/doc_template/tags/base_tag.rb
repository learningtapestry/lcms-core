# frozen_string_literal: true

module DocTemplate
  module Tags
    class BaseTag
      SOFT_RETURN_RE = /([[:graph:]]+\[|\][[:graph:]]+)/
      UNICODE_SPACES_RE = /(\u0020|\u00A0|\u1680|\u180E|[\u2000-\u200B]|\u202F|\u205F|\u3000|\uFEFF)/

      attr_reader :anchor, :content, :errors

      def self.parse(node, opts = {})
        new.parse(node, opts)
      end

      def self.tag_with_html_regexp
        @tag_with_html_regexp ||=
          begin
            raise "TAG_NAME is not specified" unless const_defined?(:TAG_NAME)

            /\[[^\]]*#{const_get(:TAG_NAME)}[[^:,;.]]*:?\s?[^\]]*\]/i
          end
      end

      #
      # There can be situations when Google Document is exported
      # in a broken way:
      #   <span>[imag</span><span style='font-family:"Montserrat"'>e: OP.LE.L1.004</span><span>]
      # In this case we need to guess the part which should be substituted
      #
      # As a result for the tag with name `image` will be the following
      #   [
      #     /\[[^\]]*image[[^:,;.]]*(<\/span>\s*<span\s?[^>]*>)?:?\s?[^\]]*\]/i,
      #     /\[[^\]]*imag[[^:,;.]]*(<\/span>\s*<span\s?[^>]*>)?e:?\s?[^\]]*\]/i,
      #     /\[[^\]]*ima[[^:,;.]]*(<\/span>\s*<span\s?[^>]*>)?ge:?\s?[^\]]*\]/i
      #   ]
      #
      # @param [Integer] min_char Minimum number of character by which we guess the tag
      # @return [Array<Regexp>]
      def self.tag_with_html_regexp_array(min_char = 3)
        @tag_with_html_regexp_array ||=
          begin
            raise "TAG_NAME is not specified" unless const_defined?(:TAG_NAME)

            tag_name = const_get(:TAG_NAME)
            (tag_name.length - 1).downto(min_char - 1).map do |idx|
              first_part = tag_name[0..idx]
              last_part = tag_name[(idx + 1)..]

              %r{\[[^\]]*#{first_part}[[^:,;.]]*(</span>\s*<span\s?[^>]*>)?#{last_part}:?\s?[^\]]*\]}i
            end
          end
      end

      #
      # @param [String] name
      # @return [String] path to the template
      #
      def self.template_path_for(name)
        Rails.root.join("lib", "doc_template", "templates", name)
      end

      def initialize
        @errors = []
      end

      #
      # Precede the specified element with tag's placeholder
      #
      def before_tag(node)
        node.before Nokogiri::HTML.fragment(placeholder)
      end

      def check_tag_soft_return(node)
        # need to remove unicode spaces bc they're not handled by [[:graph:]]
        return unless node.content.gsub(UNICODE_SPACES_RE, "") =~ SOFT_RETURN_RE

        raise DocumentError,
              "Soft return for #{self.class::TAG_NAME} detected: #{node.content}, use hard return instead"
      end

      def content_until_break(node)
        [].tap do |result| # steep:ignore
          check_tag_soft_return(node)
          while (sibling = node.next_sibling)
            break if include_break?(sibling)

            result << sibling.to_html
            sibling.remove
          end
        end.join
      end

      def content_until_materials(node)
        [].tap do |result| # steep:ignore
          check_tag_soft_return(node)
          while (sibling = node.next_sibling)
            break if include_break_for?(sibling, "stop_materials_tags")

            result << sibling.to_html
            sibling.remove
          end
        end.join
      end

      def gdoc?(opts)
        opts[:context_type].to_s.casecmp("gdoc").zero?
      end

      def include_break?(node)
        include_break_for? node, "stop_tags"
      end

      def include_break_for?(node, key)
        stop_tags = Array.wrap ::DocTemplate::Tags.config[self.class::TAG_NAME.downcase][key]
        return false if stop_tags.empty?

        tags = stop_tags.map { |t| ::DocTemplate::Tags.const_get(t)::TAG_NAME }.join("|")

        result = node.content =~ /\[\s*(#{tags})/i
        check_tag_soft_return(node) if result
        result
      end

      def materials
        @materials || []
      end

      def parse(node, _opts = {})
        @result = node
        remove_tag
        self
      end

      def parse_nested(node, opts = {})
        if node == opts[:parent_node]
          opts[:iteration] = opts[:iteration].to_i + 1
          if opts[:iteration] > DocTemplate::Document::MAX_PARSE_ITERATIONS
            raise DocumentError, "Loop detected for node:<br>#{node}"
          end
        end
        parsed = ::DocTemplate::Document.parse(Nokogiri::HTML.fragment(node), opts.merge(level: 1))
        @errors.push(*parsed.errors) if parsed.errors.any?
        # add the parts to the parent document
        opts[:parent_document].parts += parsed.parts if opts[:parent_document]
        parsed.render
      end

      def parse_template(context, template_name)
        @tmpl = context
        template = File.read template_path(template_name)
        ERB.new(template).result(binding)
      end

      def placeholder
        @placeholder ||= "{{#{placeholder_id}}}"
      end

      def placeholder_id
        @placeholder_id ||= "#{self.class.name.to_s.demodulize.underscore}_#{SecureRandom.hex(10)}"
      end

      def render
        @result.to_s.presence || placeholder
      end

      #
      # Replace the tag element with its placeholder. Or inline the
      # tag if requested
      #
      def replace_tag(node)
        replacement = @opts&.[](:explicit_render) ? content : Nokogiri::HTML.fragment(placeholder)
        node.replace replacement
      end

      #
      # Substitute only the tag markup inside `node`, leaving the element and
      # the text around the tag intact. For inline tags this is what you want:
      # `node` is the *enclosing* element (see DocTemplate::Document#parse_node,
      # which hands a tag its `node.parent`), so #replace_tag would throw away
      # the authored sentence the tag sits in. Inside a list that is worse than
      # losing text: dropping the `<li>` leaves its `<ol>` one item short, while
      # the next `<ol start="N">` chunk Google Docs emits still carries the
      # original absolute number — so the visible numbering skips.
      #
      # Falls back to #replace_tag when the tag markup cannot be located in the
      # element's HTML (e.g. an export mangled beyond FULL_TAG's reach).
      #
      def replace_tag_inline(node)
        # Locate the tag across the element's TEXT nodes, never in its
        # serialized HTML: inner_html also carries attribute values, so a
        # bracketed literal in an attribute (e.g. <img alt="Figure [1]">)
        # matches FULL_TAG first and the substitution lands there — corrupting
        # the attribute and leaving the real tag behind for the parse loop to
        # hit again. Matching the concatenated text mirrors how
        # DocTemplate::Document#parse_node identifies the tag (`node.text`), and
        # still spans a tag that a broken export split across several elements.
        text_nodes = node.xpath(".//text()").to_a
        match = DocTemplate::FULL_TAG.match(text_nodes.map(&:content).join)
        return replace_tag(node) unless match

        replacement = @opts&.[](:explicit_render) ? content.to_s : placeholder
        splice_tag(text_nodes, match, replacement)
        @result = node
      end

      #
      # Rewrites the text nodes the tag covers: the first one keeps the text
      # before the tag and receives the replacement markup; the rest lose the
      # covered slice, keeping only whatever text follows the tag. Text either
      # side is re-escaped, since only the replacement is markup.
      #
      def splice_tag(text_nodes, match, replacement)
        cursor = 0
        inserted = false

        text_nodes.each do |text_node|
          body = text_node.content
          starts_at = cursor
          cursor += body.length
          # Untouched: entirely before the tag starts, or entirely after it ends.
          next if cursor <= match.begin(0) || starts_at >= match.end(0)

          prefix = body[0, [match.begin(0) - starts_at, 0].max].to_s
          suffix = body[(match.end(0) - starts_at)..].to_s
          html = "#{ERB::Util.html_escape(prefix)}#{inserted ? '' : replacement}#{ERB::Util.html_escape(suffix)}"
          inserted = true

          html.empty? ? text_node.remove : text_node.replace(Nokogiri::HTML.fragment(html))
        end
      end

      def tag_data
        {}
      end

      #
      # First look for the template override inside possible gems
      # And use standard one if not found
      #
      def template_name(opts)
        context = opts.fetch(:context_type, :default).to_s
        override =
          ::DocTemplate::Tags.config.dig(self.class::TAG_NAME.to_s.downcase, "templates", context)
        override.presence || self.class::TEMPLATES[context.to_sym]
      end

      def template_path(name)
        custom_path =
          Array.wrap(::DocTemplate::Tags.config["templates_paths"]).detect do |path|
            File.exist?(File.join path.to_s, name)
          end
        custom_path.present? ? File.join(custom_path, name) : self.class.template_path_for(name)
      end

      private

      def remove_tag
        start_tag_index = @result.children.index(@result.at_xpath(STARTTAG_XPATH))
        end_tag_index = @result.children.index(@result.at_xpath(ENDTAG_XPATH))
        @result.children[start_tag_index..end_tag_index].each do |node|
          if node.content.match?(/.+\[[^\]]+\]|\[[^\]]+\].+/)
            # a tag followed or preceded by anything else
            # removes the tag itself - everything between `[` and `]`
            node.content = node.content.sub(/\[[^\[\]]+\]/, "")
          elsif (data = node.content.match(/^([^\[]*)\[|\]([^\[]*)$/))
            # if node contains open or closing tag bracket with general
            # text outside the bracket itself
            if (new_content = data[1].presence || data[2]).blank?
              node.remove
            else
              node.content = new_content
            end
          else
            node.remove
          end
        end
      end
    end
  end
end
