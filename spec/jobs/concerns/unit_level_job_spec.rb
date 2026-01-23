# frozen_string_literal: true

require "rails_helper"

describe UnitLevelJob do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new(ApplicationJob) do
      include ResqueJob
      include UnitLevelJob

      def perform(entry_id, options = {}); end
    end
  end

  before do
    stub_const("TestUnitLevelJob", test_class)
  end

  describe ".queued_or_running?" do
    let(:entry_id) { 123 }

    context "when a job is queued or running" do
      before do
        allow(TestUnitLevelJob).to receive(:queued_or_running_job_for)
          .with(entry_id, {})
          .and_return("job_123")
      end

      it "returns true" do
        expect(TestUnitLevelJob.queued_or_running?(entry_id)).to be true
      end
    end

    context "when no job is queued or running" do
      before do
        allow(TestUnitLevelJob).to receive(:queued_or_running_job_for)
          .with(entry_id, {})
          .and_return(nil)
      end

      it "returns false" do
        expect(TestUnitLevelJob.queued_or_running?(entry_id)).to be false
      end
    end
  end

  describe ".queued_or_running_job_for" do
    let(:entry_id) { 123 }

    context "when job is found in queue" do
      let(:job_data) do
        {
          "arguments" => [entry_id, { "initial_job_id" => "initial_456" }],
          "job_id" => "job_789"
        }
      end

      before do
        allow(TestUnitLevelJob).to receive(:find_in_queue_by_payload)
          .and_return(job_data)
      end

      it "returns the initial_job_id if present" do
        expect(TestUnitLevelJob.queued_or_running_job_for(entry_id)).to eq "initial_456"
      end
    end

    context "when job is found in working" do
      let(:job_data) do
        {
          "arguments" => [entry_id, {}],
          "job_id" => "job_789"
        }
      end

      before do
        allow(TestUnitLevelJob).to receive(:find_in_queue_by_payload)
          .and_return(nil)
        allow(TestUnitLevelJob).to receive(:find_in_working_by_payload)
          .and_return(job_data)
      end

      it "returns the job_id if no initial_job_id" do
        expect(TestUnitLevelJob.queued_or_running_job_for(entry_id)).to eq "job_789"
      end
    end

    context "when no job is found" do
      before do
        allow(TestUnitLevelJob).to receive(:find_in_queue_by_payload)
          .and_return(nil)
        allow(TestUnitLevelJob).to receive(:find_in_working_by_payload)
          .and_return(nil)
      end

      it "returns nil" do
        expect(TestUnitLevelJob.queued_or_running_job_for(entry_id)).to be_nil
      end
    end
  end
end
