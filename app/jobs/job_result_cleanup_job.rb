# frozen_string_literal: true

class JobResultCleanupJob < ApplicationJob
  queue_as :default

  def perform
    JobResult.cleanup_expired
  end
end
