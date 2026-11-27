# frozen_string_literal: true

module Admin
  # Read-only display of what a unit or section import stored on its Resource
  # (admin/shared/_resource_metadata).
  module ResourceMetadataHelper
    # A real tag: a known element name with only quoted attributes, so plain
    # text such as "a <b and c> d" or "x<y" is not mistaken for markup.
    HTML_ELEMENTS = %w(a b blockquote br div em h1 h2 h3 h4 h5 h6 hr i iframe img li ol p pre s script
                       span strong style sub sup table tbody td th thead tr u ul).freeze
    HTML_TAG = %r{</?(?:#{HTML_ELEMENTS.join("|")})(?:\s+[a-z-]+\s*=\s*(?:"[^"]*"|'[^']*'))*\s*/?>}i
    # Text formatting only: no <img>, <iframe> etc., so viewing imported
    # metadata never loads remote resources.
    ALLOWED_TAGS = %w(a b br em i li ol p strong sub sup u ul).freeze
    ALLOWED_ATTRIBUTES = %w(href).freeze

    # Renders one metadata JSONB value: arrays as a comma-separated list of
    # rendered items, hashes as pretty JSON, authored HTML (description,
    # acknowledgements…) sanitized to text formatting, and everything else
    # as plain text.
    def resource_metadata_value(value)
      case value
      when Array then safe_join(value.map { resource_metadata_value(_1) }, ", ")
      when Hash then tag.pre(JSON.pretty_generate(value), class: "mb-0 small")
      when String
        value.match?(HTML_TAG) ? sanitize(value, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES) : value
      else value.to_s
      end
    end
  end
end
