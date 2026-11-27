# frozen_string_literal: true

module DocTemplate
  #
  # Splits an authored list cell, kept as HTML, into its entries while keeping
  # each entry's inline formatting. Entries are separated by the same
  # characters as plain-text list cells (Tables::Base::SPLIT_REGEX: comma,
  # semicolon, line break) and by paragraph / line-break boundaries.
  #
  # Google Docs expresses bold and italics as styled spans
  # (`<span style="font-style:italic">`), and a separator often sits inside
  # one: "<span> by Micha Archer, [material: x]</span>". So the cell is walked
  # as text runs, each run is cut at the separators, and every piece is
  # re-wrapped in copies of the inline elements it sat in.
  #
  #   HtmlList.split('<p><span style="font-style:italic">School Map</span> (if available), Chart paper</p>')
  #   # => ['<span style="font-style:italic">School Map</span> (if available)', "Chart paper"]
  #
  module HtmlList
    INLINE_ELEMENTS = %w(a b em i s span strong sub sup u).freeze

    module_function

    # @param html [String] sanitized cell HTML
    # @return [Array<String>] entry HTML snippets, without blank entries
    def split(html)
      items = [[]]
      walk(Nokogiri::HTML.fragment(html.to_s), [], items)
      items.map(&:join).reject { Nokogiri::HTML.fragment(it).text.strip.empty? && !it.include?("<img") }
    end

    def walk(node, wrappers, items)
      node.children.each do |child|
        if child.text?
          add_text(child.text, wrappers, items)
        elsif child.element? && INLINE_ELEMENTS.include?(child.name.downcase)
          walk(child, wrappers + [child], items)
        elsif child.element? && child.name.casecmp?("img")
          items.last << wrap(child.to_html, wrappers)
        elsif child.element?
          # Block (p, div, li, ...) or <br>: an entry boundary on both sides.
          items << []
          walk(child, wrappers, items)
          items << []
        end
      end
    end

    def add_text(text, wrappers, items)
      parts = text.split(Tables::Base::SPLIT_REGEX, -1)
      parts.each_with_index do |part, index|
        items << [] if index.positive?
        part = part.sub(/\A[[:space:]]+/, "") if items.last.empty?
        part = part.sub(/[[:space:]]+\z/, "") if index < parts.size - 1
        items.last << wrap(ERB::Util.html_escape(part), wrappers) unless part.empty?
      end
    end

    def wrap(inner, wrappers)
      wrappers.reverse.reduce(inner) do |content, element|
        attributes = element.attribute_nodes.map { %( #{it.name}="#{ERB::Util.html_escape(it.value)}") }.join
        "<#{element.name}#{attributes}>#{content}</#{element.name}>"
      end
    end
  end
end
