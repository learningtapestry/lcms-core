# frozen_string_literal: true

module DocTemplate
  module Tables
    class Lesson < Base
      HEADER_LABEL = "lesson-metadata"
      HTML_VALUE_FIELDS = %w(description description-past description-future).freeze
      LABEL_OPTIONS = %w(required optional).freeze
      LMS_FIELDS = %w(lms-summary lms-summary-spanish).freeze

      def parse(fragment, *args)
        super
        return self unless @data.present?

        @data["subject"] = @data["subject"].to_s.downcase

        # Parse sub-tables
        @data["lesson_prep"] = LessonPrep.parse(fragment).data

        validate_label
        validate_lms_fields

        self
      end

      private

      def validate_label
        value = @data["lesson-label"].to_s.strip.downcase
        return if value.blank?
        return if LABEL_OPTIONS.include?(value)

        @errors << "Invalid lesson-label: '#{@data['lesson-label']}' (valid: #{LABEL_OPTIONS.join(', ')})"
      end

      def validate_lms_fields
        return if @data["lms-enabled"].to_s.casecmp("yes").zero?

        LMS_FIELDS.each do |field|
          next if @data[field].blank?

          @errors << "#{field} should be blank when lms-enabled is No"
        end
      end
    end
  end
end
