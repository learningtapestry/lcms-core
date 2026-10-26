# frozen_string_literal: true

module DocTemplate
  module Tables
    class Unit < Base
      HEADER_LABEL = "unit-metadata"
      HTML_VALUE_FIELDS = %w(description acknowledgements license).freeze
      MATERIALS_KEY = "unit-materials"
      REQUIRED_FIELDS = %w(subject grade unit-id unit-title unit-topic description).freeze
      UNIT_ID_REGEX = /\A[a-z0-9]+\z/i

      def parse(fragment, *args)
        super
        return self if @data.blank?

        @data["subject"] = @data["subject"].to_s.downcase if @data["subject"].present?
        @data["unit-id"] = @data["unit-id"].to_s.downcase if @data["unit-id"].present?
        fetch_materials(@data, MATERIALS_KEY)
        validate_required_fields
        validate_grade
        validate_unit_id
        validate_unit_materials
        self
      end

      private

      def validate_grade
        return if @data["grade"].blank? || @data["grade"].to_s.strip.match?(GRADE_REGEX)

        @errors << "Invalid grade: '#{@data['grade']}' (must be a number, K or PK)"
      end

      def validate_required_fields
        REQUIRED_FIELDS.each do |field|
          @errors << "#{field} is required" if @data[field].blank?
        end
      end

      def validate_unit_id
        return if @data["unit-id"].blank?
        return if @data["unit-id"].match?(UNIT_ID_REGEX)

        @errors << "Invalid unit-id: '#{@data['unit-id']}' (must be alphanumeric)"
      end

      def validate_unit_materials
        identifiers = material_identifiers
        return if identifiers.empty?

        resolved_ids = Array(@data["material_ids"])
        return if resolved_ids.size == identifiers.size

        known = ::Material.where(identifier: identifiers.map(&:downcase)).pluck(:identifier).to_set
        identifiers.uniq.each do |identifier|
          next if known.include?(identifier.downcase)

          @errors << "Unknown unit-materials identifier: '#{identifier}'"
        end
      end

      def material_identifiers
        @data[MATERIALS_KEY]
          .to_s
          .split(SPLIT_REGEX)
          .map(&:squish)
          .reject(&:blank?)
      end
    end
  end
end
