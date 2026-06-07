# frozen_string_literal: true

# Authentication for Mission Control Jobs is handled by Devise in routes.rb
# via `authenticated :user, ->(u) { u.admin? }`, so disable the engine's
# built-in HTTP Basic auth to avoid the duplicate filter chain.
Rails.application.config.after_initialize do
  MissionControl::Jobs.http_basic_auth_enabled = false
end
