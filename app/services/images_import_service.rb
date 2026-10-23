# frozen_string_literal: true

require "csv"

#
# Imports the image spreadsheet (a Google Sheet) that `[image: id, size]` tags
# resolve against. The sheet is the source of truth: every import replaces the
# whole table. Columns are matched by header, ignoring case, spacing and
# punctuation:
#
#   Image ID  - required; the id authors put in the tag
#   File      - required; the image's S3 URL, or its key in the app's bucket
#               (also accepted as "File URL", "URL", "S3 Key", "S3 URL", "S3 Path")
#   Caption, Credit, Alt Text - optional
#
class ImagesImportService < ImportService
  class ImportError < StandardError; end

  HEADERS = {
    identifier: %w(imageid id),
    file_url: %w(file fileurl url s3key s3url s3path),
    caption: %w(caption),
    credit: %w(credit creditline),
    alt_text: %w(alttext alt)
  }.freeze

  class << self
    #
    # @param [String] url Google Sheet link
    # @return [Integer] number of imported images
    #
    def call(url)
      rows = CSV.parse(super, headers: true)
      columns = columns_for(rows.headers)
      seen = {}
      images = rows.each_with_index.filter_map { |row, idx| build(row, columns, idx + 2, seen) }

      Image.transaction do
        Image.delete_all
        images.each(&:save!)
      end
      images.size
    end

    private

    def columns_for(headers)
      normalized = headers.to_h { [it.to_s.downcase.gsub(/[^a-z0-9]/, ""), it] }
      columns = HEADERS.transform_values { |names| normalized.values_at(*names).compact.first }
      missing = %i(identifier file_url).select { columns[it].nil? }
      raise ImportError, "The image sheet needs #{missing.map { HEADERS[it].first }.join(' and ')} columns" if missing.any?

      columns
    end

    # @param line [Integer] spreadsheet row number, for error messages
    # @param seen [Hash] identifier => row number of the rows built so far
    def build(row, columns, line, seen)
      values = columns.transform_values { |header| header && row[header].to_s.strip.presence }
      return if values.values.none?

      image = Image.new(**values, file_url: file_url_for(values[:file_url]))
      # The rows already in the table are about to be replaced, so an id they
      # hold is not "taken"; a repeat within the sheet is (checked below).
      image.validate
      image.errors.delete(:identifier, :taken)
      if image.identifier && (first = seen[image.identifier])
        image.errors.add(:identifier, "repeats row #{first}")
      end
      seen[image.identifier] ||= line if image.identifier
      return image if image.errors.empty?

      raise ImportError, "Row #{line} (#{values[:identifier] || 'no id'}): #{image.errors.full_messages.to_sentence}"
    end

    # A bare key ("images/k/u1/map.jpg") or an s3:// URI points into the app's
    # bucket; a full http(s) URL is kept as authored.
    def file_url_for(value)
      return if value.blank?
      return value if value.match?(%r{\Ahttps?://}i)

      bucket, key =
        if (match = value.match(%r{\As3://([^/]+)/(.+)\z}i))
          match.captures
        else
          [ENV.fetch("AWS_S3_BUCKET_NAME", nil), value.delete_prefix("/")]
        end
      return value if bucket.blank?

      region = ENV.fetch("AWS_REGION", nil).presence || "us-east-1"
      "https://#{bucket}.s3.#{region}.amazonaws.com/#{key.split('/').map { ERB::Util.url_encode(it) }.join('/')}"
    end
  end
end
