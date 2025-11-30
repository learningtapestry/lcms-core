# frozen_string_literal: true

module Integrations
  class WebhookCallJob < ApplicationJob
    extend ResqueJob
    include RetryDelayed

    queue_as :low

    def perform(config_id, payload)
      webhook_configuration = WebhookConfiguration.find(config_id)

      webhook_configuration.execute_call(payload)
    end
  end
end
