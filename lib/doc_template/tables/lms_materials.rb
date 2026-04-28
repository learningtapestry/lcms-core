# frozen_string_literal: true

module DocTemplate
  module Tables
    class LmsMaterials < Base
      HEADER_LABEL = "lms-materials"
      HTML_VALUE_FIELDS = [].freeze # steep:ignore

      # Parses the first lms-materials table found in the fragment.
      # Returns an Array of { "material-id" => ..., "access-type" => ... } hashes.
      def parse(fragment, *_args)
        el = fragment.at_xpath(xpath_meta_headers, XpathFunctions.new)
        return [] unless el

        table = self.class.flatten_table(el.ancestors("table").first)
        return [] unless table

        entries = table.xpath(".//tr[position() > 1]").filter_map do |row|
          material_id = row.at_xpath("./td[1]")&.text.to_s.squish
          access_type = row.at_xpath("./td[2]")&.text.to_s.squish
          next if material_id.blank?

          { "material-id" => material_id, "access-type" => access_type }
        end

        table.remove
        entries
      end
    end
  end
end
