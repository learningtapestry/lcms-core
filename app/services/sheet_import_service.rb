# frozen_string_literal: true

require "csv"

#
# Imports a Google Sheet into one table. Every row is checked before anything
# is written, so a bad or empty sheet leaves the table as it was; the write
# itself then runs in one transaction.
#
# Columns are matched by header, ignoring case, spacing and punctuation.
# Subclasses describe them and choose how rows reach the table:
#
#   COLUMNS          - { attribute => [accepted header names] }; the first name
#                      is the one quoted when the column is missing
#   REQUIRED_COLUMNS - attributes whose column must be present
#   SHEET_NAME       - used in messages ("The image sheet needs …")
#   #model           - the ActiveRecord class rows become
#   #key_for(record) - the row's identity; two rows with the same key are an
#                      error. Defaults to the record's identifier.
#   #build(values)   - the unsaved record for one row (override to transform)
#   #write(records)  - how the checked records reach the table. Defaults to
#                      replacing the whole table (#replace_all).
#
class SheetImportService
  class ImportError < StandardError; end

  REQUIRED_COLUMNS = [].freeze

  #
  # @param [String] url Google Sheet link
  # @return [Integer] number of imported rows
  #
  def self.call(url)
    new.call(url)
  end

  def call(url)
    rows = CSV.parse(ImportService.call(url), headers: true)
    columns = columns_for(rows.headers).compact
    @imported_attributes = columns.keys
    seen = {}
    records = rows.each_with_index.filter_map { |row, idx| check(row, columns, idx + 2, seen) }
    # An empty sheet is almost always the wrong link or tab, and would
    # otherwise empty the table.
    raise ImportError, "The #{self.class::SHEET_NAME} sheet has no rows" if records.empty?

    model.transaction { write(records) }
    records.size
  end

  private

  # Attributes whose column the sheet has; a missing optional column is left
  # out of each row's values (and, for an in-place sync, left untouched).
  attr_reader :imported_attributes

  def model
    raise NotImplementedError
  end

  def build(values)
    model.new(**values)
  end

  def key_for(record)
    record.identifier
  end

  # The sheet is the source of truth: the table becomes exactly its rows.
  def write(records)
    model.delete_all
    records.each(&:save!)
  end

  def columns_for(headers)
    normalized = headers.to_h { [it.to_s.downcase.gsub(/[^a-z0-9]/, ""), it] }
    columns = self.class::COLUMNS.transform_values { |names| normalized.values_at(*names).compact.first }
    missing = self.class::REQUIRED_COLUMNS.select { columns[it].nil? }
    if missing.any?
      names = missing.map { self.class::COLUMNS[it].first }.join(" and ")
      raise ImportError, "The #{self.class::SHEET_NAME} sheet needs #{names} columns"
    end

    columns
  end

  # @param line [Integer] spreadsheet row number, for error messages
  # @param seen [Hash] key => row number of the rows checked so far
  # @return [ApplicationRecord, nil] nil for a blank row
  def check(row, columns, line, seen)
    values = columns.transform_values { |header| header && row[header].to_s.strip.presence }
    return if values.values.none?

    record = build(values)
    record.validate
    # Rows already in the table are about to be replaced or updated, so a key
    # they hold is not "taken"; a repeat within the sheet is (checked below).
    record.errors.delete(key_attribute, :taken)
    key = key_for(record)
    if key.present? && (first = seen[key])
      record.errors.add(key_attribute, "repeats row #{first}")
    end
    seen[key] ||= line if key.present?
    return record if record.errors.empty?

    raise ImportError, "Row #{line} (#{values[key_attribute] || 'no id'}): #{record.errors.full_messages.to_sentence}"
  end

  # The attribute duplicate and "taken" errors are reported on.
  def key_attribute
    :identifier
  end
end
