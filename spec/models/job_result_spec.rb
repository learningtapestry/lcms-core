# frozen_string_literal: true

require "rails_helper"

RSpec.describe JobResult do
  describe "scopes" do
    describe ".expired" do
      it "returns records older than 1 hour" do
        expired = described_class.create!(job_id: "expired-1", job_class: "TestJob", created_at: 2.hours.ago)
        recent = described_class.create!(job_id: "recent-1", job_class: "TestJob", created_at: 30.minutes.ago)

        expect(described_class.expired).to include(expired)
        expect(described_class.expired).not_to include(recent)
      end
    end

    describe ".for_parent" do
      it "returns records with matching parent_job_id" do
        parent = described_class.create!(job_id: "child-1", parent_job_id: "parent-1", job_class: "TestJob")
        other = described_class.create!(job_id: "child-2", parent_job_id: "parent-2", job_class: "TestJob")

        expect(described_class.for_parent("parent-1")).to include(parent)
        expect(described_class.for_parent("parent-1")).not_to include(other)
      end
    end
  end

  describe ".cleanup_expired" do
    it "deletes expired records" do
      described_class.create!(job_id: "expired-1", job_class: "TestJob", created_at: 2.hours.ago)
      described_class.create!(job_id: "recent-1", job_class: "TestJob", created_at: 30.minutes.ago)

      expect { described_class.cleanup_expired }.to change(described_class, :count).by(-1)
      expect(described_class.find_by(job_id: "recent-1")).to be_present
    end
  end
end
