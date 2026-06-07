# frozen_string_literal: true

module NestedJobTracker
  extend ActiveSupport::Concern

  class_methods do
    def queued_or_running_nested?(job_id, current_job_id = "-1")
      check_child = ->(j) { j["arguments"][1]&.dig("initial_job_id") == job_id && j["job_id"] != current_job_id }
      job_klasses = self::NESTED_JOBS + [name]
      job_klasses.each do |job_klass|
        queued = find_in_queue_by_payload(job_klass, &check_child) ||
                 find_in_working_by_payload(job_klass, &check_child)
        return true if queued.present?
      end
      false
    end

    def status_nested(jid)
      status_batch_nested([jid]).fetch(jid, :done)
    end

    # Batch variant of #status_nested. Returns a hash keyed by job_id.
    # Resolves self-status for every jid in one query, then issues a single
    # additional query per nested job class to detect still-running children.
    def status_batch_nested(jids)
      return {} if jids.blank?

      self_statuses = status_batch(jids)
      pending_parents = self_statuses.select { |_, s| s == :done }.keys
      return self_statuses if pending_parents.empty?

      running_parents = parents_with_running_children(pending_parents)
      self_statuses.each_with_object({}) do |(jid, self_status), obj|
        obj[jid] = running_parents.include?(jid) ? :running : self_status
      end
    end

    def fetch_result_nested(jid)
      JobResult.for_parent(jid).where(job_class: self::NESTED_JOBS).pluck(:result)
    end

    # Batch variant of #fetch_result_nested. Returns a hash keyed by parent
    # job_id with arrays of result hashes for that parent's nested children.
    def fetch_results_batch_nested(jids)
      return {} if jids.blank?

      grouped = JobResult
        .for_parent(jids)
        .where(job_class: self::NESTED_JOBS)
        .pluck(:parent_job_id, :result)
        .group_by(&:first)
      jids.each_with_object({}) do |jid, obj|
        obj[jid] = (grouped[jid] || []).map(&:last)
      end
    end

    private

    # Returns the set of parent job_ids that still have at least one nested
    # child job queued or running. Uses one query per nested job class
    # (and self) to enumerate unfinished SolidQueue jobs, then groups them
    # by the parent jid embedded in their arguments.
    def parents_with_running_children(parent_jids)
      job_klasses = self::NESTED_JOBS + [name]
      parent_set = parent_jids.to_set
      running = Set.new
      job_klasses.each do |job_klass|
        SolidQueue::Job
          .where(class_name: job_klass.to_s, finished_at: nil)
          .find_each do |sq_job|
            arg = Array.wrap(sq_job.arguments).first
            next unless arg.is_a?(Hash)

            initial_jid = arg["arguments"]&.[](1)&.dig("initial_job_id")
            running << initial_jid if parent_set.include?(initial_jid)
          end
      end
      running
    end
  end

  private

  def initial_job_id
    @initial_job_id ||= options[:initial_job_id].presence || job_id
  end
end
