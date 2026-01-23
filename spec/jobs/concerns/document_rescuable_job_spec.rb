# frozen_string_literal: true

require "rails_helper"

describe DocumentRescuableJob do
  describe "module inclusion" do
    it "is included in DocumentPdfJob" do
      expect(DocumentPdfJob.ancestors).to include(described_class)
    end

    it "defines LINK_KEY constant in including class" do
      expect(DocumentPdfJob::LINK_KEY).to eq "pdf"
    end
  end

  describe "rescue_from behavior" do
    it "is configured to rescue StandardError" do
      rescue_handlers = DocumentPdfJob.rescue_handlers
      error_classes = rescue_handlers.map(&:first)
      expect(error_classes).to include("StandardError")
    end
  end
end
