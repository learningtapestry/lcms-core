# frozen_string_literal: true

require "csv"

#
# Imports the URL spreadsheet (a Google Sheet) that `[url: url_id]` tags
# resolve against. The sheet is the source of truth: every import replaces the
# whole table. Columns are matched by header, ignoring case, spacing and
# punctuation:
#
#   URL ID - required; the id authors put in the tag (also "ID")
#   URL    - required; the http(s) address (also "Link", "Href")
#   Text   - optional; shown instead of the URL (also "Link Text",
#            "Display Text", "Title", "Label")
#
class LinksImportService < ImportService
  class ImportError < StandardError; end

  HEADERS = {
    identifier: %w(urlid linkid id),
    url: %w(url link href),
    text: %w(text linktext displaytext title label)
  }.freeze

  class << self
    #
    # @param [String] url Google Sheet link
    # @return [Integer] number of imported links
    #
    def call(url)
      rows = CSV.parse(super, headers: true)
      columns = columns_for(rows.headers)
      seen = {}
      links = rows.each_with_index.filter_map { |row, idx| build(row, columns, idx + 2, seen) }

      Link.transaction do
        Link.delete_all
        links.each(&:save!)
      end
      links.size
    end

    private

    def columns_for(headers)
      normalized = headers.to_h { [it.to_s.downcase.gsub(/[^a-z0-9]/, ""), it] }
      columns = HEADERS.transform_values { |names| normalized.values_at(*names).compact.first }
      missing = %i(identifier url).select { columns[it].nil? }
      raise ImportError, "The URL sheet needs #{missing.map { HEADERS[it].first }.join(' and ')} columns" if missing.any?

      columns
    end

    # @param line [Integer] spreadsheet row number, for error messages
    # @param seen [Hash] identifier => row number of the rows built so far
    def build(row, columns, line, seen)
      values = columns.transform_values { |header| header && row[header].to_s.strip.presence }
      return if values.values.none?

      link = Link.new(**values)
      # The rows already in the table are about to be replaced, so an id they
      # hold is not "taken"; a repeat within the sheet is (checked below).
      link.validate
      link.errors.delete(:identifier, :taken)
      if link.identifier && (first = seen[link.identifier])
        link.errors.add(:identifier, "repeats row #{first}")
      end
      seen[link.identifier] ||= line if link.identifier
      return link if link.errors.empty?

      raise ImportError, "Row #{line} (#{values[:identifier] || 'no id'}): #{link.errors.full_messages.to_sentence}"
    end
  end
end
