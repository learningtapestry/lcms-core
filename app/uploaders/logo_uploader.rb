# frozen_string_literal: true

class LogoUploader < CarrierWave::Uploader::Base
  # Store in public/uploads/settings for local file storage,
  # or in the configured S3 bucket under uploads/settings when using fog.
  def store_dir
    "uploads/settings"
  end

  # Store as logo.<original-extension>. Must always return a value (CarrierWave 3.x).
  def filename
    ext = original_filename.present? ? File.extname(original_filename) : extension_fallback
    "logo#{ext}"
  end

  # Allow only image types per SETTINGS_MIME_TYPES[:image]
  def extension_allowlist
    %w[jpg jpeg png gif webp svg]
  end

  private

  def extension_fallback
    return ".#{file.extension}" if file.present? && file.respond_to?(:extension) && file.extension.present?

    ".png"
  end
end
