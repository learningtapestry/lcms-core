# frozen_string_literal: true

module JobTracker
  def self.included(base) # :nodoc:
    base.extend ClassMethods
  end

  module ClassMethods
    def find(job_id)
      find_in_queue(job_id) || find_in_working(job_id)
    end

    def find_in_queue(job_id)
      sq_job = SolidQueue::Job.find_by(active_job_id: job_id)
      sq_job if sq_job&.ready_execution&.present?
    end

    def find_in_queue_by_payload(job_class, &block)
      jobs = SolidQueue::Job
        .where(class_name: job_class.to_s, finished_at: nil)
        .where.not(id: SolidQueue::ClaimedExecution.select(:job_id))
        .flat_map { |j| Array.wrap(j.arguments) }

      return jobs unless block_given?

      jobs.detect(&block)
    end

    def find_in_working(job_id)
      sq_job = SolidQueue::Job.find_by(active_job_id: job_id)
      sq_job if sq_job&.claimed_execution&.present?
    end

    def find_in_working_by_payload(job_class, &block)
      jobs = SolidQueue::Job
        .where(class_name: job_class.to_s, finished_at: nil)
        .joins(:claimed_execution)
        .flat_map { |j| Array.wrap(j.arguments) }

      return jobs unless block_given?

      jobs.detect(&block)
    end

    def fetch_result(job_id)
      record = JobResult.find_by(job_id: job_id)
      record&.result
    end

    # Batch variant of #fetch_result. Returns a hash keyed by job_id.
    # Avoids per-jid SELECT roundtrips when many results are needed at once.
    def fetch_results_batch(job_ids)
      return {} if job_ids.blank?

      JobResult.where(job_id: job_ids).pluck(:job_id, :result).to_h
    end

    def status(job_id)
      status_batch([job_id]).fetch(job_id, :unknown)
    end

    # Batch variant of #status. Returns a hash keyed by job_id with one of
    # :waiting / :running / :scheduled / :blocked / :done / :unknown. Loads
    # all SolidQueue::Job rows and the JobResult existence flags in two
    # queries regardless of the input size.
    # :scheduled — the job is queued for a future run_at.
    # :blocked   — the job is waiting on a concurrency semaphore.
    # :unknown   — the jid is neither in the queue nor has a stored result
    #              (typically an invalid jid from a client).
    # The Reimportable UI treats every non-:done value as pending and keeps
    # polling, so introducing new pending-like values is safe.
    def status_batch(job_ids)
      return {} if job_ids.blank?

      sq_jobs = SolidQueue::Job
        .includes(:ready_execution, :claimed_execution, :failed_execution, :scheduled_execution, :blocked_execution)
        .where(active_job_id: job_ids)
        .index_by(&:active_job_id)
      finished_jids = JobResult.where(job_id: job_ids).pluck(:job_id).to_set

      job_ids.each_with_object({}) do |job_id, obj|
        sq_job = sq_jobs[job_id]
        obj[job_id] =
          if sq_job&.ready_execution.present?
            :waiting
          elsif sq_job&.claimed_execution.present?
            :running
          elsif sq_job&.scheduled_execution.present?
            :scheduled
          elsif sq_job&.blocked_execution.present?
            :blocked
          elsif sq_job&.finished? || sq_job&.failed_execution.present? || finished_jids.include?(job_id)
            :done
          else
            :unknown
          end
      end
    end
  end

  def store_initial_result(res, options = {})
    jid = options[:initial_job_id].presence || job_id
    JobResult.upsert(
      { job_id: jid, parent_job_id: nil, job_class: self.class.name, result: res },
      unique_by: :job_id
    )
  end

  #
  # @param [Hash] res
  # @param [Hash] options
  #
  def store_result(res, options = {})
    parent_jid = options[:initial_job_id].presence
    JobResult.upsert(
      { job_id: job_id, parent_job_id: parent_jid, job_class: self.class.name, result: res },
      unique_by: :job_id
    )
  end
end
