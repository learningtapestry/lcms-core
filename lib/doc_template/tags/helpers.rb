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

        descriptions = Settings.get(:documents, include_defaults: true)
                         &.dig(:priority_descriptions, self.class::TAG_NAME.downcase.to_sym)
        Array.wrap(descriptions)[priority - 1]
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
        render_tags(MaterialTokens.resolve(ERB::Util.html_escape(text)))
      end

      # Renders the tags authored inside a metadata field (activity
      # description, guidance, …) for the context type being parsed. Metadata
      # tables are removed before the document's own tags are parsed, so
      # their tags would otherwise print as literal text.
      def render_tags(html)
        DocTemplate::InlineTags.render(html, context_type: @opts&.[](:context_type) || :default)
      end

      # The authored activity-description led by the "Description:"
      # boilerplate, run into its first paragraph ("Description: In this
      # activity, …") so the label reads as part of the text. When the
      # description opens with something other than a paragraph (a list, a
      # table), the label gets its own paragraph above it.
      def labeled_description(html)
        label = ERB::Util.html_escape(I18n.t("activity.description_label"))
        fragment = Nokogiri::HTML.fragment(html.to_s)
        first = fragment.children.find { it.element? || it.text.strip.present? }

        if first&.element? && first.name == "p"
          first.prepend_child("#{label} ")
        elsif first&.text?
          return "<p>#{label} #{fragment.to_html.strip}</p>"
        else
          fragment.prepend_child("<p>#{label}</p>")
        end
        fragment.to_html
      end
    end
  end
end
