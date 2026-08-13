# frozen_string_literal: true

module DocTemplate
  module Tags
    # `[material: id]` is an inline reference: it is authored mid-sentence
    # ("provide students with copies of [material: …]."), so only the tag markup
    # is substituted — the surrounding text and its element stay put. Same
    # treatment DefTag and StandardTag give their inline tags, and the same
    # markup MaterialTokens emits for the identical reference in metadata text.
    class MaterialTag < BaseTag
      TAG_NAME = "material"

      def parse(node, opts = {})
        @opts = opts
        identifier = opts[:value].to_s.strip.downcase
        material = ::Material.find_by(identifier: identifier)

        @content =
          if material
            MaterialTokens.label_for(material, identifier)
          else
            %(<span class="badge text-bg-danger">Unknown material: #{identifier}</span>)
          end

        replace_tag_inline node
        self
      end
    end
  end

  Template.register_tag(Tags::MaterialTag::TAG_NAME, Tags::MaterialTag)
end
