# frozen_string_literal: true

class JobResult < ApplicationRecord
  scope :expired, -> { where(created_at: ...1.hour.ago) }
  scope :for_parent, ->(jid) { where(parent_job_id: jid) }

  def self.cleanup_expired
    expired.delete_all
  end
end
