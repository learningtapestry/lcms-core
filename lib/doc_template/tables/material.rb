# frozen_string_literal: true

module DocTemplate
  module Tables
    class Material < Base
      CONFIG_PATH = Rails.root.join("config", "materials_rules.yml")
      HEADER_LABEL = "material-metadata"
      HTML_VALUE_FIELDS = [].freeze # steep:ignore
      LANGUAGE_OPTIONS = ["English", "Spanish", "English, Spanish"].freeze
      NAME_DATE_OPTIONS = %w(Yes No).freeze
      ORIENTATION_OPTIONS = %w(P L portrait landscape).freeze
      REQUIRED_FIELDS = %w(material-id material-type material-title language).freeze
      MATERIAL_ID_REGEX = /\A[a-z0-9][a-z0-9._-]*\z/i

      def parse(fragment, *args)
        super
        return self unless @data.present?

        validate_required_fields
        validate_material_id
        validate_material_order
        validate_option("language", LANGUAGE_OPTIONS)
        validate_option("name-date", NAME_DATE_OPTIONS)
        validate_option("orientation", ORIENTATION_OPTIONS)

        self
      end

      private

      def config
        # TODO: Implement
        @config ||= {}
      end

      def validate_required_fields
        REQUIRED_FIELDS.each do |field|
          @errors << "#{field} is required" if @data[field].blank?
        end
      end

      def validate_material_id
        return if @data["material-id"].blank?
        return if @data["material-id"].match?(MATERIAL_ID_REGEX)

        @errors << "Invalid material-id: '#{@data['material-id']}' " \
                   "(must be alphanumeric and may include '.', '-' or '_')"
      end

      def validate_material_order
        value = @data["material-order"]
        return if value.blank?
        return if value.to_s.match?(/\A\d+\z/)

        @errors << "Invalid material-order: '#{value}' " \
                   "(must be an integer greater than or equal to 0)"
      end

      def validate_option(field, valid_values)
        value = @data[field].to_s.strip
        return if value.blank?
        return if valid_values.map(&:downcase).include?(value.downcase)

        @errors << "Invalid #{field}: '#{@data[field]}' (valid: #{valid_values.join(', ')})"
      end
    end
  end
end
