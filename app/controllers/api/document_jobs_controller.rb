# frozen_string_literal: true

module Api
  # JSON status endpoint for Document-family async jobs (PDF, GDoc, etc.).
  #
  # Decouples job-status polling from the resource type. Any job that writes
  # its result via JobTracker#store_result becomes pollable here without
  # per-resource status actions.
  #
  # Response shape:
  #   { status: "running" | "done" | "failed" | "unknown",
  #     result: <hash from store_result>,   # only when done
  #     error:  <string>                    # only when failed
  #   }
  class DocumentJobsController < ApplicationController
    respond_to :json

    def status
      job_id = params[:job_id]
      sq_job = SolidQueue::Job.find_by(active_job_id: job_id)

      if (failure = sq_job&.failed_execution)
        error_msg = failure.error.is_a?(Hash) ? failure.error["message"] : failure.error.to_s
        return render(json: { status: "failed", error: error_msg.presence || "Job failed" })
      end

      result = JobResult.find_by(job_id: job_id)
      if result&.result.present?
        render_job_result(result.result)
      elsif sq_job
        render json: { status: "running" }
      else
        render json: { status: "unknown" }
      end
    end

    private

    # JobTracker convention: failure-on-non-preview writes { ok: false, errors: [...] }.
    # Anything else with a result is treated as success.
    def render_job_result(payload)
      if payload.is_a?(Hash) && payload["ok"] == false
        error = Array.wrap(payload["errors"]).join(", ").presence || "Job failed"
        render json: { status: "failed", error: error }
      else
        render json: { status: "done", result: payload }
      end
    end
  end
end
