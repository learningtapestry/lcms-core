# frozen_string_literal: true

module DocTemplate
  module Tags
    # Shared resolution of `[material: id]` tokens found in raw metadata text
    # (lesson Materials summary, activity Materials line). Emits the same inline
    # markup as MaterialTag so a reference renders identically wherever it
    # appears. Unknown identifiers fall through to bare identifier text.
    module MaterialTokens
      MATERIAL_TOKEN_RE = /\[material:\s*([^\]]+)\]/i

      module_function

      # Downcased identifiers referenced by every `[material: id]` token in text.
      def identifiers_in(text)
        text.to_s.scan(MATERIAL_TOKEN_RE).flatten.map { |id| id.to_s.strip.downcase }.reject(&:blank?)
      end

      # Loads the referenced materials keyed by identifier, so token resolution
      # does not issue a query per token. Resolved identifiers (hits AND misses)
      # are memoized per request/job in Current, so a lesson whose N activities
      # each resolve their own Materials line reuses one cache instead of firing
      # one query per activity (the former N+1). Only identifiers not already
      # cached hit the database.
      #
      # @return [Hash{String => Material}] downcased identifier => material
      #   (misses omitted, matching the previous return shape).
      def lookup(identifiers)
        ids = Array(identifiers).map { |id| id.to_s.downcase }.reject(&:blank?).uniq
        return {} if ids.empty?

        cache = (Current.material_tokens ||= {})
        missing = ids.reject { |id| cache.key?(id) }
        if missing.any?
          found = ::Material.where(identifier: missing).index_by(&:identifier)
          missing.each { |id| cache[id] = found[id] } # nil for a miss, so it is not re-queried
        end

        ids.each_with_object({}) { |id, result| (m = cache[id]) && result[id] = m }
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
          material ? label_for(material, identifier) : identifier
        end
      end

      # Inline markup for a resolved material, shared with MaterialTag. A
      # reference is plain (italicized) text, not a link: a material is only
      # navigable from a unit bundle, where the material sits alongside the
      # lesson as its own file, so a per-instance /materials/:id URL would be
      # wrong in every context this markup actually renders in (preview, PDF,
      # Google Doc). The visible text is the material's authored title (e.g.
      # "Lesson 7 Slides"), falling back to the identifier when the material has
      # no title. The label is HTML-escaped since a title is authored text.
      def label_for(material, identifier)
        label = title_for(material).presence || identifier.downcase
        %(<span class="o-ld-material">#{ERB::Util.html_escape(label)}</span>)
      end

      # The material's authored title from its metadata (same derivation as
      # MaterialPresenter#title), or "" when it defines none.
      def title_for(material)
        DocTemplate::Objects::Material.build_from(material.metadata).material_title.to_s
      end
    end
  end
end
