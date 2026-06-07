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
        allow(TestNestedTrackerJob).to receive(:status_batch).with([jid]).and_return(jid => :done)
        allow(TestNestedTrackerJob).to receive(:parents_with_running_children).with([jid]).and_return(Set.new)
      end

      it "returns :done" do
        expect(TestNestedTrackerJob.status_nested(jid)).to eq(:done)
      end
    end

    context "when parent job is done but nested jobs are still running" do
      before do
        allow(TestNestedTrackerJob).to receive(:status_batch).with([jid]).and_return(jid => :done)
        allow(TestNestedTrackerJob).to receive(:parents_with_running_children).with([jid]).and_return(Set.new([jid]))
      end

      it "returns :running" do
        expect(TestNestedTrackerJob.status_nested(jid)).to eq(:running)
      end
    end

    context "when parent job is still waiting" do
      before do
        allow(TestNestedTrackerJob).to receive(:status_batch).with([jid]).and_return(jid => :waiting)
      end

      it "returns :waiting" do
        expect(TestNestedTrackerJob.status_nested(jid)).to eq(:waiting)
      end
    end
  end

  describe ".status_batch_nested" do
    let(:jid_done) { SecureRandom.uuid }
    let(:jid_running_children) { SecureRandom.uuid }
    let(:jid_waiting) { SecureRandom.uuid }

    before do
      allow(TestNestedTrackerJob).to receive(:status_batch).with([jid_done, jid_running_children, jid_waiting])
        .and_return(jid_done => :done, jid_running_children => :done, jid_waiting => :waiting)
      allow(TestNestedTrackerJob).to receive(:parents_with_running_children)
        .with([jid_done, jid_running_children])
        .and_return(Set.new([jid_running_children]))
    end

    it "returns :done for parents with no running children" do
      result = TestNestedTrackerJob.status_batch_nested([jid_done, jid_running_children, jid_waiting])
      expect(result[jid_done]).to eq(:done)
    end

    it "returns :running for parents whose nested children are still running" do
      result = TestNestedTrackerJob.status_batch_nested([jid_done, jid_running_children, jid_waiting])
      expect(result[jid_running_children]).to eq(:running)
    end

    it "preserves the original self-status for non-:done parents" do
      result = TestNestedTrackerJob.status_batch_nested([jid_done, jid_running_children, jid_waiting])
      expect(result[jid_waiting]).to eq(:waiting)
    end

    it "returns an empty hash for empty input" do
      expect(TestNestedTrackerJob.status_batch_nested([])).to eq({})
    end
  end

  describe ".fetch_results_batch_nested" do
    let(:parent_a) { SecureRandom.uuid }
    let(:parent_b) { SecureRandom.uuid }

    before do
      JobResult.create!(job_id: "a-1", parent_job_id: parent_a, job_class: "DocumentPdfJob", result: { ok: true, p: "a" })
      JobResult.create!(job_id: "a-2", parent_job_id: parent_a, job_class: "MaterialPdfJob", result: { ok: false, p: "a" })
      JobResult.create!(job_id: "b-1", parent_job_id: parent_b, job_class: "DocumentPdfJob", result: { ok: true, p: "b" })
      JobResult.create!(job_id: "alien", parent_job_id: parent_a, job_class: "SomeUnrelatedJob", result: { alien: true })
    end

    it "groups results by parent_job_id" do
      result = TestNestedTrackerJob.fetch_results_batch_nested([parent_a, parent_b])
      expect(result[parent_a].size).to eq(2)
      expect(result[parent_b].size).to eq(1)
    end

    it "filters out job classes not listed in NESTED_JOBS" do
      result = TestNestedTrackerJob.fetch_results_batch_nested([parent_a])
      expect(result[parent_a]).not_to include(hash_including("alien" => true))
    end

    it "returns an empty array for parents with no nested results" do
      result = TestNestedTrackerJob.fetch_results_batch_nested([SecureRandom.uuid])
      expect(result.values.first).to eq([])
    end

    it "returns an empty hash for empty input" do
      expect(TestNestedTrackerJob.fetch_results_batch_nested([])).to eq({})
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
