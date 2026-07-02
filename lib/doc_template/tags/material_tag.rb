# frozen_string_literal: true

module DocTemplate
  module Tags
    class MaterialTag < BaseTag
      TAG_NAME = "material"

      def parse(node, opts = {})
        @opts = opts
        identifier = opts[:value].to_s.strip.downcase
        material = ::Material.find_by(identifier: identifier)

        @content =
          if material
            MaterialTokens.link_for(material, identifier)
          else
            %(<span class="badge text-bg-danger">Unknown material: #{identifier}</span>)
          end

        replace_tag node
        self
      end
    end
  end

  Template.register_tag(Tags::MaterialTag::TAG_NAME, Tags::MaterialTag)
end
