# frozen_string_literal: true

module DocTemplate
  module Tags
    module Helpers
      include ActionView::Helpers::TagHelper

      # English cardinal words for the system-generated activity ordinal
      # ("Activity One", "Activity Two", ...). The activity index is 1-based.
      NUMBER_WORDS = %w(Zero One Two Three Four Five Six Seven Eight Nine Ten
                        Eleven Twelve Thirteen Fourteen Fifteen Sixteen Seventeen
                        Eighteen Nineteen Twenty).freeze

      # Per-grouping material fields aggregated into the activity "Materials:"
      # line. Mirrors the lesson-level Materials table (DocumentPresenter).
      ACTIVITY_MATERIALS_FIELDS = %i(activity_materials_student activity_materials_pair
                                     activity_materials_group activity_materials_class
                                     activity_materials_teacher).freeze

      def materials_container(props)
        return if props.nil?

        content_tag(:div, nil, data: { react_class: "MaterialsContainer", react_props: props }) { _1 }
      end

      # English cardinal word for a 1-based number, e.g. 1 => "One". Falls back
      # to the numeral past the lookup table; blank for nil.
      def number_to_word(num)
        return "" if num.blank?

        NUMBER_WORDS[num.to_i] || num.to_s
      end

      # Compiles an activity's per-grouping material fields into a single
      # de-duplicated, comma-joined string for the "Materials:" line.
      def activity_materials_list(activity)
        ACTIVITY_MATERIALS_FIELDS
          .flat_map { |field| activity.public_send(field).to_s.split(",") }
          .map(&:strip)
          .reject(&:blank?)
          .uniq
          .join(", ")
      end

      def priority_description(activity)
        priority = activity.try(:activity_priority) || activity.priority
        return unless priority.present?

        config = Tags.config[self.class::TAG_NAME.downcase]
        Array.wrap(config["priority_descriptions"])[priority - 1]
      end

      # Replaces `[material: id]` tokens in the activity Materials line with the
      # same inline link markup MaterialTag emits, batch-loading the referenced
      # materials in a single query. Unknown identifiers fall through to bare text.
      def resolve_material_tokens(text)
        MaterialTokens.resolve(text)
      end
    end
  end
end
