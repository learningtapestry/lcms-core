# frozen_string_literal: true

module DocTemplate
  module Tables
    class LessonPrep < Base
      HEADER_LABEL = "lesson-prep"
      # Directions carry rich formatting (sub-headings + nested lists) that the
      # Lesson Preparation section renders verbatim, so capture them as HTML.
      HTML_VALUE_FIELDS = %w(lesson-prep-directions).freeze
    end
  end
end
