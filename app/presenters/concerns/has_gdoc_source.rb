# frozen_string_literal: true

# Adds accessors for the Google Docs source link stored under
# +links["source"]["gdoc"]+. Intended to be included in presenters whose
# underlying record exposes a +links+ JSONB attribute with this structure.
module HasGdocSource
  extend ActiveSupport::Concern

  # Returns the display name of the Google Docs source.
  #
  # @return [String, nil] the source name, or +nil+ when the link is missing
  def source_name
    links.dig("source", "gdoc", "name")
  end

  # Returns the URL of the Google Docs source.
  #
  # @return [String, nil] the source URL, or +nil+ when the link is missing
  def source_url
    links.dig("source", "gdoc", "url")
  end

  # Returns when the Google Docs source was last imported.
  #
  # @return [Time, nil] the import time, or +nil+ when it was never recorded
  def source_imported_at
    timestamp = links.dig("source", "gdoc", "timestamp")
    Time.zone.at(timestamp.to_i) if timestamp.present?
  end
end
