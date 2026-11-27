# frozen_string_literal: true

require "rails_helper"

describe BaseBundleJob do
  describe "#perform" do
    it "raises NotImplementedError" do
      job = described_class.new
      expect { job.perform(1) }.to raise_error(NotImplementedError)
    end
  end

  describe "private methods" do
    let(:job) { described_class.new }

    describe "#generate_bundle" do
      it "raises NotImplementedError" do
        expect { job.send(:generate_bundle) }.to raise_error(NotImplementedError)
      end
    end

    describe "#generate_dependants" do
      it "raises NotImplementedError" do
        expect { job.send(:generate_dependants) }.to raise_error(NotImplementedError)
      end
    end
  end

  describe "#perform_generation_for" do
    let(:unit) { create(:resource, :unit) }
    let(:job_class) do
      Class.new(described_class) do
        const_set(:CONTENT_TYPE, :test_bundle)

        def perform(entry_id, options = {}) = perform_generation_for(entry_id, options)

        private

        def generate_bundle = "https://s3.test/bundle"
        def bundle_warnings = ["2 files skipped"]
      end
    end
    let(:job) { job_class.new }

    before do
      stub_const("TestBundleJob", job_class)
      allow(job_class).to receive(:queued_or_running_nested?).and_return(false)
      allow(job).to receive(:store_initial_result)
    end

    it "stores the bundle's warnings with its link" do
      job.perform(unit.id)

      expect(job).to have_received(:store_initial_result)
        .with(hash_including(ok: true, link: "https://s3.test/bundle", warnings: ["2 files skipped"]), anything)
    end
  end

  describe "#with_dependants?" do
    let(:job) { described_class.new }

    before do
      job.instance_variable_set(:@options, options)
    end

    context "when with_dependants option is present" do
      let(:options) { { with_dependants: true } }

      it "returns true" do
        expect(job.send(:with_dependants?)).to be true
      end
    end

    context "when with_dependants option is not present" do
      let(:options) { {} }

      it "returns false" do
        expect(job.send(:with_dependants?)).to be false
      end
    end

    context "when with_dependants option is false" do
      let(:options) { { with_dependants: false } }

      it "returns false" do
        expect(job.send(:with_dependants?)).to be false
      end
    end
  end
end
