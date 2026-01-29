# frozen_string_literal: true

require "rails_helper"

describe MaterialRescuableJob do
  describe "module inclusion" do
    it "is included in MaterialPdfJob" do
      expect(MaterialPdfJob.ancestors).to include(described_class)
    end

    it "defines LINK_KEY constant in including class" do
      expect(MaterialPdfJob::LINK_KEY).to eq "pdf"
    end
  end

  describe "rescue_from behavior" do
    it "is configured to rescue StandardError" do
      rescue_handlers = MaterialPdfJob.rescue_handlers
      error_classes = rescue_handlers.map(&:first)
      expect(error_classes).to include("StandardError")
    end
  end
end
