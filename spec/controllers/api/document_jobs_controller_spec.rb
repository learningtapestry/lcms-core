# frozen_string_literal: true

require "rails_helper"

describe Api::DocumentJobsController do
  let(:user)   { create :admin }
  let(:job_id) { "job_abc_123" }

  before { sign_in user }

  describe "#status" do
    subject(:do_request) { get :status, params: { job_id: job_id } }

    # The controller eager-loads execution associations to stay consistent
    # with JobTracker.status_batch. Stub the relation so .find_by is reached.
    let(:relation) { class_double(SolidQueue::Job) }

    before do
      allow(SolidQueue::Job).to receive(:includes)
        .with(:ready_execution, :claimed_execution, :failed_execution, :scheduled_execution, :blocked_execution)
        .and_return(relation)
    end

    context "when the job has failed via Solid Queue" do
      # The real FailedExecution.message reads error["message"] from the
      # serialized JSON column. We mock the delegated method directly.
      let(:failed_execution) { instance_double(SolidQueue::FailedExecution, message: "boom") }
      let(:sq_job)           { instance_double(SolidQueue::Job, failed_execution: failed_execution) }

      before { allow(relation).to receive(:find_by).with(active_job_id: job_id).and_return(sq_job) }

      it "returns a failed status with the underlying error message" do
        do_request
        body = response.parsed_body
        expect(body["status"]).to eq("failed")
        expect(body["error"]).to eq("boom")
      end
    end

    context "when the job completed successfully" do
      before do
        allow(relation).to receive(:find_by).with(active_job_id: job_id).and_return(nil)
        JobResult.create!(job_id: job_id, job_class: "DocumentPdfJob",
                          result: { "url" => "http://example.com/x.pdf", "pages" => 12 })
      end

      it "returns a done status with the stored result payload" do
        do_request
        body = response.parsed_body
        expect(body["status"]).to eq("done")
        expect(body["result"]).to eq("url" => "http://example.com/x.pdf", "pages" => 12)
      end
    end

    context "when JobResult stores an `ok: false` failure record (non-preview failure path)" do
      before do
        allow(relation).to receive(:find_by).with(active_job_id: job_id).and_return(nil)
        JobResult.create!(job_id: job_id, job_class: "DocumentPdfJob",
                          result: { "ok" => false, "errors" => ["doc name", "PrinceXML failed"] })
      end

      it "returns a failed status with the joined error message" do
        do_request
        body = response.parsed_body
        expect(body["status"]).to eq("failed")
        expect(body["error"]).to include("PrinceXML failed")
      end
    end

    context "when the job is still in the queue (no result, sq_job present)" do
      let(:sq_job) { instance_double(SolidQueue::Job, failed_execution: nil, finished?: false) }

      before do
        allow(relation).to receive(:find_by).with(active_job_id: job_id).and_return(sq_job)
      end

      it "returns a running status" do
        do_request
        expect(response.parsed_body).to eq("status" => "running")
      end
    end

    context "when sq_job is finished but no JobResult was written (legacy job)" do
      let(:sq_job) { instance_double(SolidQueue::Job, failed_execution: nil, finished?: true) }

      before do
        allow(relation).to receive(:find_by).with(active_job_id: job_id).and_return(sq_job)
      end

      it "treats the SolidQueue finished marker as success" do
        do_request
        expect(response.parsed_body).to eq("status" => "done")
      end
    end

    context "when neither sq_job nor JobResult exists (unknown job_id)" do
      before { allow(relation).to receive(:find_by).with(active_job_id: job_id).and_return(nil) }

      it "returns an unknown status" do
        do_request
        expect(response.parsed_body).to eq("status" => "unknown")
      end
    end

    context "when the request is unauthenticated" do
      before { sign_out user }

      it "redirects to login (Devise authenticate_user!)" do
        do_request
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
