# frozen_string_literal: true

require "rails_helper"

RSpec.describe NestedJobTracker do
  let(:test_class) do
    Class.new(ApplicationJob) do
      include JobTracker
      include NestedJobTracker

      queue_as :default

      def perform(entry_id, options = {}); end
    end
  end

  before do
    stub_const("TestNestedTrackerJob", test_class)
    stub_const("TestNestedTrackerJob::NESTED_JOBS", %w(DocumentPdfJob MaterialPdfJob).freeze)
  end

  describe ".status_nested" do
    let(:jid) { SecureRandom.uuid }

    context "when parent job is done and no nested jobs are running" do
      before do
        allow(TestNestedTrackerJob).to receive(:status).with(jid).and_return(:done)
        allow(TestNestedTrackerJob).to receive(:queued_or_running_nested?).with(jid).and_return(false)
      end

      it "returns :done" do
        expect(TestNestedTrackerJob.status_nested(jid)).to eq(:done)
      end
    end

    context "when parent job is done but nested jobs are still running" do
      before do
        allow(TestNestedTrackerJob).to receive(:status).with(jid).and_return(:done)
        allow(TestNestedTrackerJob).to receive(:queued_or_running_nested?).with(jid).and_return(true)
      end

      it "returns :running" do
        expect(TestNestedTrackerJob.status_nested(jid)).to eq(:running)
      end
    end

    context "when parent job is still waiting" do
      before do
        allow(TestNestedTrackerJob).to receive(:status).with(jid).and_return(:waiting)
      end

      it "returns :waiting" do
        expect(TestNestedTrackerJob.status_nested(jid)).to eq(:waiting)
      end
    end
  end

  describe ".fetch_result_nested" do
    let(:parent_jid) { SecureRandom.uuid }

    before do
      JobResult.create!(job_id: "child-1", parent_job_id: parent_jid, job_class: "DocumentPdfJob", result: { ok: true })
      JobResult.create!(job_id: "child-2", parent_job_id: parent_jid, job_class: "MaterialPdfJob", result: { ok: false, errors: ["fail"] })
      JobResult.create!(job_id: "other-1", parent_job_id: "other-parent", job_class: "DocumentPdfJob", result: { ok: true })
      JobResult.create!(job_id: "alien-1", parent_job_id: parent_jid, job_class: "SomeUnrelatedJob", result: { ok: true, alien: true })
    end

    it "returns results for all nested jobs with the given parent_job_id" do
      results = TestNestedTrackerJob.fetch_result_nested(parent_jid)
      expect(results.size).to eq(2)
      expect(results).to include({ "ok" => true })
      expect(results).to include({ "ok" => false, "errors" => ["fail"] })
    end

    it "does not return results from other parents" do
      results = TestNestedTrackerJob.fetch_result_nested(parent_jid)
      expect(results.size).to eq(2)
    end

    it "filters out results from job classes not listed in NESTED_JOBS" do
      results = TestNestedTrackerJob.fetch_result_nested(parent_jid)
      expect(results).not_to include(hash_including("alien" => true))
    end

    it "excludes the parent's own result (stored via store_initial_result with parent_job_id: nil)" do
      JobResult.create!(job_id: parent_jid, parent_job_id: nil, job_class: "DocumentPdfJob", result: { ok: true, parent: true })

      results = TestNestedTrackerJob.fetch_result_nested(parent_jid)
      expect(results).not_to include(hash_including("parent" => true))
      expect(results.size).to eq(2)
    end

    it "returns an empty array when no nested results exist for the parent" do
      expect(TestNestedTrackerJob.fetch_result_nested(SecureRandom.uuid)).to eq([])
    end
  end
end
