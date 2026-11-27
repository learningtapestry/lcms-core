# frozen_string_literal: true

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
class ImagesImportService < SheetImportService
  SHEET_NAME = "image"
  COLUMNS = {
    identifier: %w(imageid id),
    file_url: %w(file fileurl url s3key s3url s3path),
    caption: %w(caption),
    credit: %w(credit creditline),
    alt_text: %w(alttext alt)
  }.freeze
  REQUIRED_COLUMNS = %i(identifier file_url).freeze

  private

  def model
    Image
  end

  def build(values)
    Image.new(**values, file_url: file_url_for(values[:file_url]))
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
