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

      content, remote_type = fetch_remote(url)
      return nil if content.blank?

      mime = mime_for(url, content, remote_type)
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

    # Returns [body, content_type] where content_type is the HTTP
    # Content-Type reported by the server (nil for local/unknown), so callers
    # can determine the MIME type even when the URL has no file extension.
    def fetch_remote(url)
      uri = URI.parse(url)
      case uri.scheme
      when "http", "https"
        remote_type = nil
        body = uri.open(
          open_timeout: DATA_URI_OPEN_TIMEOUT,
          read_timeout: DATA_URI_READ_TIMEOUT,
          content_length_proc: ->(size) {
            if size && size > DATA_URI_FETCH_LIMIT
              raise "remote asset too large: #{size} bytes"
            end
          }
        ) do |io|
          remote_type = io.content_type
          io.read(DATA_URI_FETCH_LIMIT + 1)
        end
        raise "remote asset exceeds #{DATA_URI_FETCH_LIMIT} bytes" if body.bytesize > DATA_URI_FETCH_LIMIT

        [body, remote_type]
      else
        raise "unsupported URL scheme: #{uri.scheme.inspect}"
      end
    end

    # Resolves the MIME type from (in order): SVG sniffing, the URL extension,
    # then the server-reported Content-Type. Only falls back to
    # application/octet-stream when none of these yield an image type — a URL
    # with no recognizable extension (e.g. a CDN path) still gets a usable
    # MIME from its Content-Type so the data URI renders as an image.
    def mime_for(url, content, remote_type = nil)
      ext = File.extname(URI.parse(url).path).delete_prefix(".").downcase
      return "image/svg+xml" if ext == "svg" || content.byteslice(0, 256).to_s.lstrip.start_with?("<svg", "<?xml")

      from_ext = Mime::Type.lookup_by_extension(ext)&.to_s
      return from_ext if from_ext

      normalized = remote_type.to_s[/\A[^;]+/].to_s.strip.presence
      return normalized if normalized && normalized != "application/octet-stream"

      "application/octet-stream"
    end
  end
end
