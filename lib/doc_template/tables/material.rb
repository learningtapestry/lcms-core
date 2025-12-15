# frozen_string_literal: true

module DocTemplate
  module Tables
    class Material < Base
      CONFIG_PATH = Rails.root.join("config", "materials_rules.yml")
      HEADER_LABEL = "material-metadata"
      HTML_VALUE_FIELDS = [].freeze # steep:ignore

      private

      def config
        # TODO: Implement
        @config ||= {}
      end
    end
  end
end
