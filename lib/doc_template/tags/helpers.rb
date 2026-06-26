# frozen_string_literal: true

module DocTemplate
  module Tags
    module Helpers
      include ActionView::Helpers::TagHelper

      def materials_container(props)
        return if props.nil?

        content_tag(:div, nil, data: { react_class: "MaterialsContainer", react_props: props }) { _1 }
      end

      def priority_description(activity)
        priority = activity.try(:activity_priority) || activity.priority
        return unless priority.present?

        config = Tags.config[self.class::TAG_NAME.downcase]
        Array.wrap(config["priority_descriptions"])[priority - 1]
      end

      # Replaces `[material: id]` tokens in plain text with the italicized
      # identifier markup that MaterialTag emits inline. Used in the
      # activity Materials line so authored tokens render the same as in
      # the body. Unknown identifiers fall through to bare identifier text.
      MATERIAL_TOKEN_RE = /\[material:\s*([^\]]+)\]/i

      def resolve_material_tokens(text)
        text.to_s.gsub(MATERIAL_TOKEN_RE) do
          identifier = ::Regexp.last_match(1).to_s.strip
          next identifier if identifier.blank?

          if ::Material.exists?(identifier: identifier.downcase)
            %(<a class="o-ld-material">#{identifier}</a>)
          else
            identifier
          end
        end
      end
    end
  end
end
