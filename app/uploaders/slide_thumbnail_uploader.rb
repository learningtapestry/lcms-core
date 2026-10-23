# frozen_string_literal: true

# Thumbnails of Google Slides pages rendered by `[slide: id, n, size]` tags.
# A subclass of ImageUploader for its raster-only allowlists, random filename
# and public (non-expiring) S3 URL: the URL is embedded in generated documents.
class SlideThumbnailUploader < ImageUploader
  def store_dir
    "uploads/slides"
  end
end
