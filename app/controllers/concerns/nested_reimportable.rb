# frozen_string_literal: true

module NestedReimportable
  private

  #
  # @param job_class [Class] The job class.
  # @return [Hash] The status of the job.
  #
  def import_status_for_nested(job_class)
    jids = params.fetch(:jids, [])
    return {} if jids.empty?

    statuses = job_class.status_batch_nested(jids)
    done_jids = statuses.select { |_, s| s == :done }.keys
    self_results = job_class.fetch_results_batch(done_jids)
    nested_results = job_class.fetch_results_batch_nested(done_jids)

    jids.each_with_object({}) do |jid, obj|
      status = statuses[jid]
      obj[jid] = {
        status:,
        result: (status == :done ? flatten_result(self_results[jid], nested_results[jid] || []) : nil)
      }.compact
    end
  end

  #
  # @param jid_res [Hash, nil] The result of the parent job.
  # @param result_nested [Array<Hash>] The results of the nested jobs.
  # @return [Hash] The flattened result.
  #
  def flatten_result(jid_res, result_nested)
    # Return in case of no errors
    return jid_res unless result_nested.any? { _1["ok"] == false }

    { ok: false, errors: jid_res&.[]("errors") || [] }.tap do |failed_result|
      result_nested.select { _1["ok"] == false }.each do |e|
        failed_result[:errors] << "<a href=\"#{e['link']}\">Source</a>: #{(e['errors'] || []).join(', ')}"
      end
    end
  end
end
