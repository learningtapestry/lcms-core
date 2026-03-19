# frozen_string_literal: true

require "rails_helper"

RSpec.describe JobTracker do
  let(:test_class) do
    Class.new(ApplicationJob) do
      include JobTracker
      queue_as :default

      def perform; end
    end
  end

  before { stub_const("TestTrackerJob", test_class) }

  describe ".status" do
    let(:job_id) { SecureRandom.uuid }

    context "when job has a result in the database" do
      before do
        JobResult.create!(job_id: job_id, job_class: "TestTrackerJob", result: { ok: true })
      end

      it "returns :done" do
        expect(TestTrackerJob.status(job_id)).to eq(:done)
      end
    end

    context "when job is unknown" do
      it "returns :done" do
        expect(TestTrackerJob.status(SecureRandom.uuid)).to eq(:done)
      end
    end
  end

  describe ".fetch_result" do
    let(:job_id) { SecureRandom.uuid }

    context "when result exists" do
      before do
        JobResult.create!(job_id: job_id, job_class: "TestTrackerJob", result: { "ok" => true, "link" => "https://example.com" })
      end

      it "returns the result hash" do
        result = TestTrackerJob.fetch_result(job_id)
        expect(result).to eq({ "ok" => true, "link" => "https://example.com" })
      end
    end

    context "when result does not exist" do
      it "returns nil" do
        expect(TestTrackerJob.fetch_result(SecureRandom.uuid)).to be_nil
      end
    end
  end

  describe ".result_key" do
    it "returns a key with underscored class name and job_id" do
      expect(TestTrackerJob.result_key("abc123")).to eq("test_tracker_job:abc123")
    end
  end

  describe "#store_result" do
    let(:job) { TestTrackerJob.new }

    it "stores result in JobResult table" do
      result = { ok: true, link: "https://example.com" }
      job.store_result(result)

      stored = JobResult.find_by(job_id: job.job_id)
      expect(stored).to be_present
      expect(stored.result).to eq(result.stringify_keys)
    end

    it "stores result with parent_job_id when initial_job_id is provided" do
      result = { ok: true }
      job.store_result(result, initial_job_id: "parent-123")

      stored = JobResult.find_by(job_id: job.job_id)
      expect(stored.parent_job_id).to eq("parent-123")
    end
  end

  describe "#store_initial_result" do
    let(:job) { TestTrackerJob.new }

    it "stores result keyed by job_id" do
      result = { ok: true }
      job.store_initial_result(result)

      stored = JobResult.find_by(job_id: job.job_id)
      expect(stored).to be_present
      expect(stored.result).to eq(result.stringify_keys)
    end

    it "stores result keyed by initial_job_id when provided" do
      result = { ok: true }
      job.store_initial_result(result, initial_job_id: "initial-456")

      stored = JobResult.find_by(job_id: "initial-456")
      expect(stored).to be_present
    end
  end
end
