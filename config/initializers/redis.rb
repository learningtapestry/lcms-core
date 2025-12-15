# frozen_string_literal: true

require "redis"

# Configure Redis for storing large flash messages and other application needs
Rails.application.config.redis = Redis.new(
  url: ENV.fetch("REDIS_URL", "redis://localhost:6379"),
  driver: :hiredis
)
