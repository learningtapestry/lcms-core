# frozen_string_literal: true

module DocTemplate
  #
  # Renders the tags authored inside a metadata field (a lesson description,
  # Lesson Preparation, an activity description, a unit's acknowledgements, …)
  # the way the same tags render in a document body. Metadata tables are cut
  # out of the document before its tags are parsed, so without this a
  # `[url: id]` or `[image: id]` in a metadata cell would print as literal text.
  #
  # Tags are rendered in place (no part placeholders), for one context type,
  # since a tag can render differently in the PDF and the Google Doc.
  #
  module InlineTags
    WRAP_ATTR = "data-inline-tags-wrap"

    module_function

    # @param html [String] the field's HTML as stored
    # @param context_type [Symbol, String] :default (PDF/preview) or :gdoc
    # @return [String] HTML with every tag rendered
    def render(html, context_type: :default)
      return html.to_s unless html.to_s.include?("[")

      fragment = Nokogiri::HTML.fragment("<div>#{html}</div>")
      root = fragment.at_css("div")
      wrap_loose_text(root)
      DocTemplate::Document.parse(fragment, context_type: context_type.to_s, explicit_render: true)
      root.xpath(".//*[@data-parsed]").each { it.remove_attribute("data-parsed") }
      root.css("span[#{WRAP_ATTR}]").each { it.replace(it.children) }
      root.inner_html
    rescue StandardError => e
      # A stray "[" with no closing bracket, or a tag that cannot render
      # outside a document: show the field as authored rather than fail the
      # whole page.
      Rails.logger.warn("DocTemplate::InlineTags: #{e.class}: #{e.message}")
      html.to_s
    end

    # Plain-text fields are escaped first, so only the tags become markup.
    def render_text(text, context_type: :default)
      render(ERB::Util.html_escape(text.to_s), context_type:)
    end

    # Document#parse finds tags inside <span>s, which is how Google exports
    # text. A field stored as plain text (or text beside markup) gets its
    # loose text nodes wrapped so their tags are found too; the wrappers are
    # removed once the tags are rendered.
    def wrap_loose_text(root)
      root.xpath(".//text()[contains(., '[')]").each do |text|
        next if text.parent.name == "span"

        text.wrap(%(<span #{WRAP_ATTR}=""></span>))
      end
    end
  end
end
