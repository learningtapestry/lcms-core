# frozen_string_literal: true

require "rails_helper"

describe ImportForm do
  let(:credentials) { double }

  before { allow_any_instance_of(described_class).to receive(:google_credentials).and_return(credentials) }

  describe "#save" do
    context "when link is present" do
      let(:form) { described_class.new(link: "http://example.com/doc") }

      it "yields to the block and returns true" do
        called = false
        result = form.save { called = true }
        expect(called).to be true
        expect(result).to be true
      end

      it "captures exceptions and adds them as errors" do
        result = form.save { raise StandardError, "something went wrong" }
        expect(result).to be false
        expect(form.errors[:link]).to include("something went wrong")
      end
    end

    context "when link is blank" do
      let(:form) { described_class.new }

      it "returns false without yielding" do
        called = false
        result = form.save { called = true }
        expect(called).to be false
        expect(result).to be false
      end

      it "has validation errors on link" do
        form.save { }
        expect(form.errors[:link]).to be_present
      end
    end
  end

  describe "#service_errors" do
    it "defaults to empty array" do
      form = described_class.new(link: "http://example.com/doc")
      expect(form.service_errors).to eq []
    end
  end
end
