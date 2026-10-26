# frozen_string_literal: true

require "carrierwave/processing/mini_magick"

# Cover image for a unit's Teacher Edition (admin Units > Edit, rendered by
# app/views/units/{pdf,gdoc}/_cover.html.erb).
#
# A subclass of ImageUploader so it keeps the same raster-only allowlists, the
# unique random filename and the public (non-expiring) S3 URL — the URL is
# persisted on the unit and embedded in generated documents.
class UnitCoverUploader < ImageUploader
  include CarrierWave::MiniMagick

  # Longest edge kept for the stored image.
  #
  # The cover spans the page content width: 7.5in on Letter with the spec's
  # 0.5in margins. At the 300dpi the PDF printers are configured with
  # (Settings::DEFAULTS[:pdf][:default][:image_dpi]) that is 2250px. Stock
  # photos are often 5000px+ and several MB, which would exceed the 5MB cap on
  # inlining an image as a data URI (AssetHelper::DATA_URI_FETCH_LIMIT) and
  # silently fall back to a remote URL that Google may not be able to fetch.
  MAX_EDGE = 2250

  # Only ever shrinks; aspect ratio is preserved.
  process resize_to_limit: [MAX_EDGE, MAX_EDGE]

  # Not ImageUploader's uploads/settings: a cover URL is client-supplied, and
  # .delete_by_url removes the previous cover, so sharing the directory would
  # let a cover pointed at the Settings brandmark delete it.
  def store_dir
    "uploads/covers"
  end
end
