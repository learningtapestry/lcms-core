# frozen_string_literal: true

module RetryDelayed
  extend ActiveSupport::Concern

  RETRY_DELAYS = [30.seconds, 1.minute, 3.minutes, 7.minutes].freeze
  MIN_DELAY_MULTIPLIER = 1.0
  MAX_DELAY_MULTIPLIER = 5.0

  # Google Apps Script PAGE_BREAK errors are non-recoverable
  class NonRecoverableScriptError < StandardError; end

  included do
    # Order matters: rescue_from handlers are checked in reverse declaration order.
    # retry_on is declared first (checked second), discard_on second (checked first).
    retry_on StandardError,
            attempts: RETRY_DELAYS.size + 1,
            wait: ->(executions) {
              delay = RETRY_DELAYS[executions - 1] || RETRY_DELAYS.last
              delay * rand(MIN_DELAY_MULTIPLIER..MAX_DELAY_MULTIPLIER)
            }

    discard_on NonRecoverableScriptError

    # Convert PAGE_BREAK script errors to NonRecoverableScriptError so discard_on can catch them
    around_perform do |_job, block|
      block.call
    rescue StandardError => e
      if e.message =~ /Script error message/ && e.message =~ /PAGE_BREAK/
        raise NonRecoverableScriptError, e.message
      end

      raise
    end
  end
end
