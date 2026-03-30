# frozen_string_literal: true

module DocTemplate
  module Objects
    class Lesson < Base
      attribute :cc_attribution, :string, default: ""
      attribute :description, :string, default: ""
      attribute :description_past, :string, default: ""
      attribute :description_future, :string, default: ""
      attribute :grade, :integer
      attribute :learning_targets, :string, default: ""
      attribute :lesson, :string, default: ""
      attribute :lesson_label, :string, default: ""
      attribute :lesson_number, :integer
      attribute :lesson_objective, :string, default: ""
      attribute :lesson_standard, :string, default: ""
      attribute :lesson_title, :string, default: ""
      attribute :lesson_title_spanish, :string, default: ""
      attribute :lesson_type, :string, default: "core"
      attribute :lms_enabled, :boolean, default: false
      attribute :lms_summary, :string, default: ""
      attribute :lms_summary_spanish, :string, default: ""
      attribute :materials, :string, default: ""
      attribute :preparation, :string, default: ""
      attribute :section, :string, default: ""
      attribute :section_number, :integer
      attribute :standard, :string, default: ""
      attribute :standards, :string, default: ""
      attribute :teaser, :string, default: ""
      attribute :title, :string, default: ""
      attribute :type, :string, default: "core"
      attribute :unit, :string, default: ""
      attribute :unit_id, :string, default: ""

      attr_accessor :lesson_prep

      class << self
        def build_from(data)
          data = prepare_data(data)
          lesson_prep_data = data.delete("lesson_prep")
          instance = new(data)
          instance.lesson_prep = LessonPrep.build_from(lesson_prep_data || {})
          instance
        end
      end
    end
  end
end
