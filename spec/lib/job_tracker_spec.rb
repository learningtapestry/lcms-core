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
      it "returns :unknown" do
        expect(TestTrackerJob.status(SecureRandom.uuid)).to eq(:unknown)
      end
    end
  end

  describe ".status_batch" do
    let(:jid_done) { SecureRandom.uuid }
    let(:jid_unknown) { SecureRandom.uuid }

    before do
      JobResult.create!(job_id: jid_done, job_class: "TestTrackerJob", result: { ok: true })
    end

    it "returns a hash keyed by job_id" do
      result = TestTrackerJob.status_batch([jid_done, jid_unknown])
      expect(result.keys).to contain_exactly(jid_done, jid_unknown)
      expect(result[jid_done]).to eq(:done)
      expect(result[jid_unknown]).to eq(:unknown)
    end

    it "returns an empty hash for empty input" do
      expect(TestTrackerJob.status_batch([])).to eq({})
    end

    it "loads SolidQueue jobs in a single query" do
      jids = Array.new(5) { SecureRandom.uuid }
      expect(SolidQueue::Job).to receive(:includes).once.and_call_original
      TestTrackerJob.status_batch(jids)
    end
  end

  describe ".fetch_results_batch" do
    let(:jid_one) { SecureRandom.uuid }
    let(:jid_two) { SecureRandom.uuid }

    before do
      JobResult.create!(job_id: jid_one, job_class: "TestTrackerJob", result: { "ok" => true })
      JobResult.create!(job_id: jid_two, job_class: "TestTrackerJob", result: { "ok" => false })
    end

    it "returns results keyed by job_id" do
      result = TestTrackerJob.fetch_results_batch([jid_one, jid_two])
      expect(result).to eq(jid_one => { "ok" => true }, jid_two => { "ok" => false })
    end

    it "omits missing job_ids from the hash" do
      result = TestTrackerJob.fetch_results_batch([jid_one, "missing"])
      expect(result.keys).to contain_exactly(jid_one)
    end

    it "returns an empty hash for empty input" do
      expect(TestTrackerJob.fetch_results_batch([])).to eq({})
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
