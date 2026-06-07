# frozen_string_literal: true

# == Schema Information
#
# Table name: job_results
#
#  id            :bigint           not null, primary key
#  job_class     :string           not null
#  result        :jsonb
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  job_id        :string           not null
#  parent_job_id :string
#
# Indexes
#
#  index_job_results_on_job_id                       (job_id) UNIQUE
#  index_job_results_on_parent_job_id                (parent_job_id)
#  index_job_results_on_parent_job_id_and_job_class  (parent_job_id,job_class)
#
class JobResult < ApplicationRecord
  # Use GREATEST(created_at, updated_at) so a record refreshed via upsert
  # (which may bump updated_at without touching created_at) is not cleaned
  # up as expired while still being actively written to.
  scope :expired, -> { where("GREATEST(created_at, updated_at) < ?", 1.hour.ago) }
  scope :for_parent, ->(jid) { where(parent_job_id: jid) }

  def self.cleanup_expired
    expired.delete_all
  end
end
