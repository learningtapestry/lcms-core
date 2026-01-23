# frozen_string_literal: true

module UnitLevelJob
  extend ActiveSupport::Concern

  class_methods do
    #
    # Check if there is a queued or running job for the given entry
    #
    # @param [Integer] entry_id
    # @param [Hash] options
    # @return [Boolean]
    #
    def queued_or_running?(entry_id, options = {})
      queued_or_running_job_for(entry_id, options).present?
    end

    #
    # Find queued or running job for the given entry
    #
    # @param [Integer] entry_id
    # @param [Hash] options
    # @return [String | NilClass] job_id or initial_job_id
    #
    def queued_or_running_job_for(entry_id, options = {})
      options = options.with_indifferent_access
      check_global_id = proc { |job|
        job.dig("arguments", 0) == entry_id
      }
      job_class = send(:to_s)
      data = find_in_queue_by_payload(job_class, &check_global_id) ||
             find_in_working_by_payload(job_class, &check_global_id)
      return unless data.present?

      data.dig("arguments", 1, "initial_job_id") || data["job_id"]
    end
  end

  private

  def same_self?(job)
    job.is_a?(Hash) && job["job_id"] != job_id &&
      job["arguments"].first == unit.id
  end

  def queued?
    self.class.find_in_queue_by_payload(self.class.name, &method(:same_self?)) ||
      self.class.find_in_working_by_payload(self.class.name, &method(:same_self?))
  end
end
