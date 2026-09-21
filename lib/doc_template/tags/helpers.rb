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
      # Splits on the same separators as Tables::Base#fetch_materials, which
      # resolves `[material: id]` tokens from these very cells — a
      # semicolon-separated cell would otherwise render as one run-on entry.
      def activity_materials_list(activity)
        ACTIVITY_MATERIALS_FIELDS
          .flat_map { |field| activity.public_send(field).to_s.split(DocTemplate::Tables::Base::SPLIT_REGEX) }
          .map(&:strip)
          .reject(&:blank?)
          .uniq
          .join(", ")
      end

      # Converts a stored `student-grouping` value (e.g. "small group") into its
      # client-configurable display label, using the Settings student_groupings
      # map (see admin Settings > Documents). Unlike lesson_types, the map's
      # keys are the fixed, validated GROUPING_OPTIONS vocabulary — no
      # case-folding needed — so the lookup is by exact key, falling back to
      # titleizing the raw value when it isn't configured (mirrors
      # DocumentPresenter#lesson_type_label's fallback).
      def student_grouping_label(value)
        Settings.map_label(:student_groupings, value)
      end

      # Converts a stored `activity-type` value (e.g. "warm-up") into its
      # client-configurable display label, using the Settings activity_types map
      # (see admin Settings > Documents). Like lesson_types, the operator defines
      # the abbr => label pairs, so the lookup is case-insensitive and falls back
      # to titleizing the raw value when it isn't configured (mirrors
      # DocumentPresenter#lesson_type_label).
      def activity_type_label(value)
        Settings.map_label(:activity_types, value)
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
      #
      # The source cells hold DECODED PLAIN TEXT (activity-materials-* is not in
      # Tables::Activity::HTML_VALUE_FIELDS) but both activity templates emit the
      # result with `raw`, so the authored text is escaped first — otherwise an
      # entry like "Beaker <250 ml>" is parsed as a tag and silently disappears
      # from the rendered line. `[material: id]` tokens survive escaping
      # untouched, so resolution still works. Mirrors
      # DocumentPresenter#materials_summary, which escapes the same values for
      # the lesson-level Materials table.
      def resolve_material_tokens(text)
        MaterialTokens.resolve(ERB::Util.html_escape(text))
      end
    end
  end
end
