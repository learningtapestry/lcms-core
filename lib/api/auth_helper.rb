# frozen_string_literal: true

module Api
  module AuthHelper
    def self.compute_hmac_signature(timestamp, path, body, secret_key)
      data = "#{timestamp}#{path}#{body}"
      OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new("sha256"),
        secret_key,
        data
      )
    end
  end
end
