# frozen_string_literal: true

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
class LinksImportService < SheetImportService
  SHEET_NAME = "URL"
  COLUMNS = {
    identifier: %w(urlid linkid id),
    url: %w(url link href),
    text: %w(text linktext displaytext title label)
  }.freeze
  REQUIRED_COLUMNS = %i(identifier url).freeze

  private

  def model
    Link
  end
end
