# frozen_string_literal: true

module DocTemplate
  module Validators
    class LmsHierarchyValidator
      attr_reader :errors

      def initialize(lesson_data, activity_data_list)
        @lesson_data = lesson_data
        @activity_data_list = activity_data_list
        @errors = []
      end

      def validate
        return @errors if @lesson_data["lms-enabled"].to_s.casecmp("yes").zero?

        @activity_data_list.each do |activity|
          next unless activity["lms-enabled"].to_s.casecmp("yes").zero?

          @errors << "Activity '#{activity['activity-title']}' has lms-enabled=Yes " \
                     "but lesson has lms-enabled=No"
        end
        @errors
      end
    end
  end
end
