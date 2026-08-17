# frozen_string_literal: true

require "open-uri"

module AssetHelper
  REDIS_PREFIX = "ub-b64-asset"
  DATA_URI_FETCH_LIMIT = 5.megabytes
  DATA_URI_OPEN_TIMEOUT = 5
  DATA_URI_READ_TIMEOUT = 10
  # Wall-clock ceiling for one remote fetch. read_timeout only bounds a SINGLE
  # read, so a server dripping a byte just inside it can hold an export job open
  # indefinitely; this bounds the whole transfer. Generous for a ≤5 MB asset.
  DATA_URI_TOTAL_TIMEOUT = 30

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

      # Per-request/job memo (reset by Rails between units of work): a document
      # render inlines the same URL more than once (e.g. several callouts of one
      # type share an icon), and each inline is a blocking remote fetch. Memoize
      # the result — including a nil failure — so the same URL is fetched at most
      # once per render regardless of the Redis cache flag.
      memo = (Current.inline_data_uris ||= {})
      return memo[url] if memo.key?(url)

      memo[url] = build_inline_data_uri(url, cache:)
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

    def build_inline_data_uri(url, cache:)
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

    # open-uri progress callback that aborts a transfer once it passes
    # DATA_URI_FETCH_LIMIT. Extracted so the bound is testable without a server.
    def fetch_limit_guard
      lambda do |transferred|
        raise "remote asset exceeds #{DATA_URI_FETCH_LIMIT} bytes" if transferred.to_i > DATA_URI_FETCH_LIMIT
      end
    end

    # Returns [body, content_type] where content_type is the HTTP
    # Content-Type reported by the server (nil for local/unknown), so callers
    # can determine the MIME type even when the URL has no file extension.
    def fetch_remote(url)
      uri = URI.parse(url)
      case uri.scheme
      when "http", "https"
        remote_type = nil
        body = Timeout.timeout(DATA_URI_TOTAL_TIMEOUT) do
          uri.open(
            open_timeout: DATA_URI_OPEN_TIMEOUT,
            read_timeout: DATA_URI_READ_TIMEOUT,
            # Declared size, when the server sends one: rejects an oversized
            # asset before a single byte is transferred.
            content_length_proc: ->(size) {
              if size && size > DATA_URI_FETCH_LIMIT
                raise "remote asset too large: #{size} bytes"
              end
            },
            # Transferred size, always: a chunked response carries no
            # Content-Length, so content_length_proc never fires and open-uri
            # would stream the WHOLE body (spilling to a Tempfile) before the
            # block below could look at it. progress_proc is called with the
            # running total as it downloads, so raising here aborts the
            # transfer mid-stream instead of after the fact.
            progress_proc: fetch_limit_guard
          ) do |io|
            remote_type = io.content_type
            io.read(DATA_URI_FETCH_LIMIT + 1)
          end
        end
        raise "remote asset exceeds #{DATA_URI_FETCH_LIMIT} bytes" if body.bytesize > DATA_URI_FETCH_LIMIT

        [body, remote_type]
      else
        raise "unsupported URL scheme: #{uri.scheme.inspect}"
      end
    end

    # Resolves the MIME type from (in order): SVG sniffing, an *image* URL
    # extension, the server-reported Content-Type, then a non-image extension.
    # Only falls back to application/octet-stream when none of these yield a
    # type — so a URL served as an image (via Content-Type) still renders in the
    # data URI even when its path has no, or a non-image, extension.
    def mime_for(url, content, remote_type = nil)
      ext = File.extname(URI.parse(url).path).delete_prefix(".").downcase
      return "image/svg+xml" if ext == "svg" || svg_content?(content)

      from_ext = Mime::Type.lookup_by_extension(ext)&.to_s
      # Only an image extension is authoritative. A recognized NON-image
      # extension (e.g. a handler URL ending .txt/.html that actually serves an
      # image) must NOT win over the server Content-Type, or the data: URI gets
      # a non-image MIME and the <img> renders broken.
      return from_ext if from_ext&.start_with?("image/")

      normalized = remote_type.to_s[/\A[^;]+/].to_s.strip.presence
      return normalized if normalized && normalized != "application/octet-stream"

      from_ext.presence || "application/octet-stream"
    end

    # True only for actual SVG payloads: a leading `<svg` tag, or an XML prolog
    # (`<?xml …`) whose head contains an `<svg` element. A plain, non-SVG XML
    # document (which also starts with `<?xml`) is NOT reported as SVG, so its
    # server Content-Type / extension can win instead of a wrong image MIME.
    def svg_content?(content)
      head = content.byteslice(0, 256).to_s.lstrip
      return true if head.start_with?("<svg")

      head.start_with?("<?xml") && content.byteslice(0, 1024).to_s.include?("<svg")
    end
  end
end
