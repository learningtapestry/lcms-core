# frozen_string_literal: true

module DocTemplate
  module Tags
    #
    # `[url: url_id]` is an inline hyperlink to a row of the URL spreadsheet
    # (Link, imported by LinksImportService). The tag becomes the sheet's text
    # linked to its URL, or the URL itself when the sheet has no text. Only the
    # tag is substituted, so the surrounding sentence and its formatting stay.
    # Anything after a comma (the spec writes `[url: url_id,]`) is ignored.
    # Unknown ids render an error badge, like unknown material tags.
    #
    class UrlTag < BaseTag
      TAG_NAME = "url"

      def parse(node, opts = {})
        @opts = opts
        identifier = opts[:value].to_s.split(",").first.to_s.strip
        link = ::Link.find_by_identifier(identifier)

        @content =
          if link
            %(<a href="#{ERB::Util.html_escape(link.url)}">#{ERB::Util.html_escape(link.label)}</a>)
          else
            %(<span class="badge text-bg-danger">Unknown URL: #{ERB::Util.html_escape(identifier.downcase)}</span>)
          end

        replace_tag_inline node
        self
      end
    end
  end

  Template.register_tag(Tags::UrlTag::TAG_NAME, Tags::UrlTag)
end
