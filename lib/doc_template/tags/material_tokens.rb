# frozen_string_literal: true

module DocTemplate
  module Tags
    # Shared resolution of `[material: id]` tokens found in raw metadata text
    # (lesson Materials summary, activity Materials line). Emits the same inline
    # link markup as MaterialTag so a reference renders identically wherever it
    # appears. Unknown identifiers fall through to bare identifier text.
    module MaterialTokens
      MATERIAL_TOKEN_RE = /\[material:\s*([^\]]+)\]/i

      module_function

      # Downcased identifiers referenced by every `[material: id]` token in text.
      def identifiers_in(text)
        text.to_s.scan(MATERIAL_TOKEN_RE).flatten.map { |id| id.to_s.strip.downcase }.reject(&:blank?)
      end

      # Loads the referenced materials in a single query, keyed by identifier,
      # so token resolution does not issue a query per token.
      #
      # @return [Hash{String => Material}] downcased identifier => material.
      def lookup(identifiers)
        ids = Array(identifiers).map { |id| id.to_s.downcase }.reject(&:blank?).uniq
        return {} if ids.empty?

        ::Material.where(identifier: ids).index_by(&:identifier)
      end

      # Replaces `[material: id]` tokens with MaterialTag-style links. Pass a
      # preloaded `known` map (from .lookup) to resolve many strings against a
      # single query; when omitted, the tokens in `text` are batched-loaded once.
      def resolve(text, known: nil)
        str = text.to_s
        known ||= lookup(identifiers_in(str))
        str.gsub(MATERIAL_TOKEN_RE) do
          identifier = ::Regexp.last_match(1).to_s.strip
          next identifier if identifier.blank?

          material = known[identifier.downcase]
          material ? link_for(material, identifier) : identifier
        end
      end

      # Inline anchor markup for a resolved material, shared with MaterialTag.
      def link_for(material, identifier)
        %(<a href="/materials/#{material.id}" class="o-ld-material" target="_blank" rel="noopener">) \
          "#{identifier.downcase}</a>"
      end
    end
  end
end
