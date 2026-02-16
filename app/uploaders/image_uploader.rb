# frozen_string_literal: true

class ImageUploader < CarrierWave::Uploader::Base
  MIME_TO_EXTENSION = {
    "image/png" => ".png",
    "image/jpeg" => ".jpg",
    "image/jpg" => ".jpg",
    "image/gif" => ".gif",
    "image/webp" => ".webp",
    "image/svg+xml" => ".svg"
  }.freeze

  def store_dir
    "uploads/settings"
  end

  def filename
    ext = original_filename.present? ? File.extname(original_filename) : extension_fallback
    @filename_cache ||= "#{SecureRandom.hex(8)}#{ext}"
  end

  def extension_allowlist
    %w(jpg jpeg png gif webp svg)
  end

  private

  def extension_fallback
    return ".#{file.extension}" if file.present? && file.respond_to?(:extension) && file.extension.present?
    return extension_from_mime_type if file.present? && file.respond_to?(:content_type) && file.content_type.present?

    raise CarrierWave::IntegrityError, "Unable to determine file type"
  end

  def extension_from_mime_type
    ext = MIME_TO_EXTENSION[file.content_type]
    raise CarrierWave::IntegrityError, "Unsupported file type: #{file.content_type}" if ext.blank?

    ext
  end
end
