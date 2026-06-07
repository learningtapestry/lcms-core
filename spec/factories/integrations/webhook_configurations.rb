# frozen_string_literal: true

# == Schema Information
#
# Table name: lcms_engine_integrations_webhook_configurations
#
#  id               :bigint           not null, primary key
#  action           :string           default("post"), not null
#  active           :boolean          default(TRUE)
#  auth_credentials :jsonb
#  auth_type        :string
#  endpoint_url     :string           not null
#  event_name       :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_webhook_configurations_on_event_name  (event_name)
#
FactoryBot.define do
  factory :webhook_configuration, class: Integrations::WebhookConfiguration do
    event_name { "event_name" }
    endpoint_url { "http://example.com" }
    action { "post" }
    auth_type { nil }
    auth_credentials { nil }

    trait :basic_auth do
      auth_type { "basic" }
      auth_credentials { { username: "username", password: "password" } }
    end

    trait :bearer_auth do
      auth_type { "bearer" }
      auth_credentials { { token: "token" } }
    end

    trait :hmac_auth do
      auth_type { "hmac" }
      auth_credentials { { secret_key: "secret" } }
    end
  end
end
