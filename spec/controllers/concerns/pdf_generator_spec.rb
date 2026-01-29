# frozen_string_literal: true

require "rails_helper"

describe PdfGenerator do
  describe "REIMPORT_PARAMS" do
    it "has unit_bundle_pdf configuration" do
      config = described_class::REIMPORT_PARAMS[:unit_bundle_pdf]
      expect(config[:job_class]).to eq UnitBundlePdfJob
      expect(config[:options]).to eq({ with_dependants: true })
      expect(config[:query]).to eq Admin::UnitsQuery
      expect(config[:props]).to have_key(:links)
      expect(config[:props]).to have_key(:polling_path)
    end

    it "has proper query_extra_attrs for unit_bundle_pdf" do
      config = described_class::REIMPORT_PARAMS[:unit_bundle_pdf]
      expect(config[:query_extra_attrs]).to eq %i(subject)
    end
  end

  describe "PREVIEW_LINKS" do
    it "is defined as a hash" do
      expect(described_class::PREVIEW_LINKS).to be_a(Hash)
    end
  end
end
