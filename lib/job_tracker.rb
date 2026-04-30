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

    def result_key(job_id)
      [name.underscore, job_id].join(":")
    end

    def status(job_id)
      sq_job = SolidQueue::Job
        .includes(:ready_execution, :claimed_execution, :failed_execution, :scheduled_execution, :blocked_execution)
        .find_by(active_job_id: job_id)
      if sq_job
        # TODO: map :scheduled_execution and :blocked_execution to dedicated statuses.
        # The initial Resque-based tracker didn't distinguish these states either; kept
        # for behavioural parity during the Solid Queue migration.
        return :waiting if sq_job.ready_execution.present?
        return :running if sq_job.claimed_execution.present?
        return :done if sq_job.finished?
        return :done if sq_job.failed_execution.present?
      end

      # Check if result exists (job already finished and was cleared)
      return :done if JobResult.exists?(job_id: job_id)

      :done
    end
  end

  def result_key
    @result_key ||= self.class.result_key(job_id)
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
