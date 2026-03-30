# frozen_string_literal: true

module DocTemplate
  module Tables
    class Activity < Base
      HEADER_LABEL = "activity-metadata"
      HTML_VALUE_FIELDS = %w(activity-description).freeze
      MATERIALS_KEYS = %w(activity-materials-student activity-materials-pair
                          activity-materials-group activity-materials-class
                          activity-metadata-teacher).freeze
      GROUPING_OPTIONS = ["individual", "partners", "small group", "class"].freeze
      LMS_TYPE_OPTIONS = %w(assignment discussion assessment reference).freeze
      LMS_FIELDS = %w(lms-title lms-title-spanish lms-instructions
                       lms-instructions-spanish lms-type).freeze
      ACCESS_TYPE_OPTIONS = %w(individual-submission shared-submission view-only).freeze

      def parse(fragment, *args)
        template_type = args.extract_options![:template_type].presence || "core"
        idx = 0
        [].tap do |result| # steep:ignore
          fragment.xpath(xpath_meta_headers, XpathFunctions.new).each do |el|
            table = self.class.flatten_table(el.ancestors("table").first)
            data = fetch table

            data = process_title(data)

            # Places activity type tags
            if data["activity-title"].present?
              idx += 1
              # we define the tag value as an unique(-ish) anchor, so we can retrieve this activity
              # info later (check toc_helpers#find_by_anchor). Used for building the sections TOC
              value = "#{idx}-#{template_type}-l2-#{data['activity-title']}".parameterize
              data["idx"] = idx
              data["anchor"] = value
              header = "<p><span>[#{::DocTemplate::Tags::ActivityMetadataTypeTag::TAG_NAME}: #{value}]</span></p>"
              table.add_next_sibling header
            end

            # Parse lms-materials table that may follow this activity
            lms_materials = LmsMaterials.parse(fragment)
            data["lms-materials"] = lms_materials unless lms_materials.empty?

            table.remove
            all_material_ids = MATERIALS_KEYS.flat_map do |key|
              fetch_materials(data, key)
              data.delete("material_ids") || []
            end
            data["material_ids"] = all_material_ids

            validate_activity(data)

            result << data
          end
        end
      end

      private

      def validate_activity(data)
        label = "Activity '#{data['activity-title']}'"

        validate_option(data, "student-grouping", GROUPING_OPTIONS, label)
        validate_option(data, "lms-type", LMS_TYPE_OPTIONS, label)
        validate_lms_fields(data, label)
        validate_access_types(data["lms-materials"] || [])
      end

      def validate_option(data, field, valid_values, label)
        value = data[field].to_s.strip.downcase
        return if value.blank?
        return if valid_values.include?(value)

        @errors << "#{label}: invalid #{field}: '#{data[field]}' (valid: #{valid_values.join(', ')})"
      end

      def validate_lms_fields(data, label)
        return if data["lms-enabled"].to_s.casecmp("yes").zero?

        LMS_FIELDS.each do |field|
          next if data[field].blank?

          @errors << "#{label}: #{field} should be blank when lms-enabled is No"
        end
      end

      def validate_access_types(entries)
        entries.each do |entry|
          access_type = entry["access-type"].to_s.strip
          next if access_type.blank?
          next if ACCESS_TYPE_OPTIONS.include?(access_type.downcase)

          @errors << "lms-materials '#{entry['material-id']}': invalid access-type '#{access_type}' " \
                     "(valid: #{ACCESS_TYPE_OPTIONS.join(', ')})"
        end
      end

      def process_title(data)
        # Allows to handle ELA as Math:
        # - inject `section-title` to link to fake section
        # - substitute activity title
        data["section-title"] ||= Tables::Section::FAKE_SECTION_TITLE
        data["activity-title"] ||= data["number"]
        data
      end
    end
  end
end
