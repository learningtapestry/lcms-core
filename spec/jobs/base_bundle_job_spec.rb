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
