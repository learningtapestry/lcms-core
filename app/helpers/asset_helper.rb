# frozen_string_literal: true

require "open-uri"

module AssetHelper
  REDIS_PREFIX = "ub-b64-asset"
  DATA_URI_FETCH_LIMIT = 5.megabytes
  DATA_URI_OPEN_TIMEOUT = 5
  DATA_URI_READ_TIMEOUT = 10

  class << self
    def base64_encoded(path, cache: false)
      key = "#{REDIS_PREFIX}#{path}"

      if cache
        b64_asset = redis.get(key)
        return b64_asset if b64_asset.present?
      end

      b64_asset = encode path
      redis.set key, b64_asset, ex: 1.day.to_i if cache
      b64_asset
    end

    # Fetches a remote (or local) URL and returns a base64 data URI suitable
    # for embedding in HTML that gets imported by Google Drive (which strips
    # or fails to fetch external image references during HTML→Gdoc import).
    # Returns nil and logs a warning on failure so callers can fall back.
    def inline_data_uri(url, cache: false)
      return nil if url.blank?

      key = "#{REDIS_PREFIX}-data-uri:#{Digest::SHA1.hexdigest(url)}"
      if cache
        cached = redis.get(key)
        return cached if cached.present?
      end

      content = fetch_remote(url)
      return nil if content.blank?

      mime = mime_for(url, content)
      encoded = Base64.strict_encode64(content)
      data_uri = "data:#{mime};base64,#{encoded}"

      redis.set(key, data_uri, ex: 1.day.to_i) if cache
      data_uri
    rescue StandardError => e
      Rails.logger.warn "AssetHelper.inline_data_uri failed for #{url}: #{e.message}"
      nil
    end

    def inlined(path)
      if Rails.env.development? || Rails.env.test? || Rails.env.qa?
        asset = Rails.application.assets.find_asset(path)
      else
        filesystem_path = Rails.application.assets_manifest.assets[path]
        asset = File.read(Rails.root.join("public", "assets", filesystem_path))
      end
      asset
    end

    private

    def encode(path)
      if Rails.env.development? || Rails.env.test? || Rails.env.qa?
        asset = Rails.application.assets.find_asset(path)
        content_type = asset&.content_type
      elsif (filesystem_path = Rails.application.assets_manifest.assets[path])
        asset = File.read(Rails.root.join("public", "assets", filesystem_path))
        content_type = Mime::Type.lookup_by_extension(File.extname(path).split(".").last)
      end
      raise "Could not find asset '#{path}'" if asset.nil?
      raise "Unknown MimeType for asset '#{path}'" if content_type.nil?

      encoded = Base64.encode64(asset.to_s).gsub(/\s+/, "")
      "data:#{content_type};base64,#{Rack::Utils.escape(encoded)}"
    end

    def redis
      Rails.application.config.redis
    end

    def fetch_remote(url)
      uri = URI.parse(url)
      case uri.scheme
      when "http", "https"
        uri.open(
          open_timeout: DATA_URI_OPEN_TIMEOUT,
          read_timeout: DATA_URI_READ_TIMEOUT,
          content_length_proc: ->(size) {
            if size && size > DATA_URI_FETCH_LIMIT
              raise "remote asset too large: #{size} bytes"
            end
          }
        ) { |io| io.read(DATA_URI_FETCH_LIMIT + 1) }.then do |body|
          raise "remote asset exceeds #{DATA_URI_FETCH_LIMIT} bytes" if body.bytesize > DATA_URI_FETCH_LIMIT

          body
        end
      else
        raise "unsupported URL scheme: #{uri.scheme.inspect}"
      end
    end

    def mime_for(url, content)
      ext = File.extname(URI.parse(url).path).delete_prefix(".").downcase
      return "image/svg+xml" if ext == "svg" || content.byteslice(0, 256).to_s.lstrip.start_with?("<svg", "<?xml")

      Mime::Type.lookup_by_extension(ext)&.to_s || "application/octet-stream"
    end
  end
end
