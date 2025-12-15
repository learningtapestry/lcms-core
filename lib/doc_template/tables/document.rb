# frozen_string_literal: true

module DocTemplate
  module Tables
    class Document < Base
      HEADER_LABEL = "document-metadata"
      HTML_VALUE_FIELDS = %w(description lesson-objective look-fors materials preparation).freeze

      def parse(fragment, *args)
        super
        @data["subject"] = @data["subject"].to_s.downcase if @data.present?
        self
      end
    end
  end
end
