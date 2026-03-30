# frozen_string_literal: true

module DocTemplate
  module Objects
    class Activity < Base
      include DocTemplate::Objects::TocHelpers

      class Item < Base
        attribute :activity_type, :string
        attribute :activity_type_purpose, :string
        attribute :activity_title, :string
        attribute :activity_title_spanish, :string
        attribute :activity_time, :integer, default: 0
        attribute :activity_description, :string
        attribute :activity_label, :string
        attribute :activity_priority, :integer, default: 0
        attribute :activity_source, :string
        attribute :activity_source_materials, :string
        attribute :activity_materials, :string
        attribute :activity_materials_student, :string
        attribute :activity_materials_pair, :string
        attribute :activity_materials_group, :string
        attribute :activity_materials_class, :string
        attribute :activity_metadata_teacher, :string
        attribute :activity_standard, :string
        attribute :activity_mathematical_practice, :string
        attribute :activity_metacognition, :string
        attribute :activity_guidance, :string
        attribute :activity_content_development_notes, :string
        attribute :alert, :string
        attribute :optional, :boolean, default: false
        attribute :slide_id, :string
        attribute :vocabulary, :string
        attribute :student_grouping, :string

        # LMS integration attributes
        attribute :lms_enabled, :boolean, default: false
        attribute :lms_title, :string
        attribute :lms_title_spanish, :string
        attribute :lms_instructions, :string
        attribute :lms_instructions_spanish, :string
        attribute :lms_type, :string

        # Submission and grading attributes
        attribute :submission_type, :string
        attribute :submission_required, :boolean, default: false
        attribute :grading_format, :string
        attribute :grading_required, :boolean, default: false
        attribute :total_points, :string

        # toc attributes
        attribute :anchor, :string
        attribute :handled, :boolean, default: false
        attribute :idx, :integer
        attribute :level, :integer, default: 2

        attribute :lms_materials, :json_array, default: -> { [] }
        attribute :material_ids, :json_array, default: -> { [] }

        # Aliases mirroring prefixed fields — used by TocHelpers, MetadataHelpers, and tag classes
        def title    = activity_title
        def time     = activity_time
        def priority = activity_priority
      end

      attr_accessor :children

      attribute :idx, :integer
      attribute :task_counter, :json_hash, default: -> { {} }

      def initialize(attrs = {})
        attrs = attrs.to_h.stringify_keys
        children_data = attrs.delete("children") || []
        known = self.class.attribute_names.map(&:to_s)
        super(attrs.select { |k, _| known.include?(k) })
        @children = children_data.map { |c| c.is_a?(Item) ? c : Item.new(c) }
      end

      def self.build_from(data)
        copy = Marshal.load Marshal.dump(data)
        activity_data =
          copy.map do |d|
            d.transform_keys! { |k| k.to_s.underscore }
            d.transform_values! { |v| Base.coerce_boolean(v) }
            d["activity_time"] = d["activity_time"].to_s[/\d+/].to_i
            d["optional"] = d["activity_label"]&.casecmp("optional")&.zero?

            apply_defaults(d)
            d
          end
        new(set_index(children: activity_data))
      end

      def self.apply_defaults(data)
        # lms-title: if blank, use activity-title
        data["lms_title"] = data["activity_title"] if data["lms_title"].blank?
        data["lms_title_spanish"] = data["activity_title_spanish"] if data["lms_title_spanish"].blank?

        # submission-required inferred from submission-type
        if data["submission_type"].present? && data["submission_required"] != true
          data["submission_required"] = true
        end

        # grading-required inferred from grading-format
        if data["grading_format"].present? && data["grading_required"] != true
          data["grading_required"] = true
        end
      end
      private_class_method :apply_defaults
    end
  end
end
