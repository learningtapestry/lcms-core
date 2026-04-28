# frozen_string_literal: true

module DocTemplate
  module Tables
    class ExternalAssetRepresentation < Base
      HEADER_LABEL = "external-asset-representation-metadata"
      HTML_VALUE_FIELDS = [].freeze # steep:ignore
      URL_FIELDS = %w(pdf doc slides sheet form video webpage).freeze

      def parse(fragment, *args)
        super
        return self unless @data.present?

        validate_urls
        self
      end

      private

      def validate_urls
        URL_FIELDS.each do |field|
          value = @data[field].to_s.strip
          next if value.blank?
          next if value.match?(URI::DEFAULT_PARSER.make_regexp(%w(http https)))

          @errors << "Invalid #{field} URL: '#{value}'"
        end
      end
    end
  end
end
