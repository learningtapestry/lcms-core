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

  # Deletes a previously uploaded image by its URL.
  # Supports both local files and S3-hosted images.
  def self.delete_by_url(url)
    return if url.blank?

    if local_url?(url)
      delete_local(url)
    elsif s3_url?(url)
      delete_from_s3(url)
    end
  rescue StandardError => e
    Rails.logger.warn "Failed to delete old image: #{e.message}"
  end

  def self.local_url?(url)
    url.to_s.start_with?("/uploads/settings/")
  end

  def self.s3_url?(url)
    url.to_s.include?("s3") || url.to_s.include?("amazonaws")
  end

  def self.delete_local(url)
    path = Rails.root.join("public", url.to_s.delete_prefix("/"))
    FileUtils.rm_f(path) if path.exist?
  end

  def self.delete_from_s3(url)
    uri = URI.parse(url)
    key = URI.decode_www_form_component(uri.path.delete_prefix("/"))
    return unless key.start_with?("uploads/settings/")

    S3Service.delete_object(key)
  end

  private_class_method :local_url?, :s3_url?, :delete_local, :delete_from_s3

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
