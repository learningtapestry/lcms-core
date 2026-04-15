# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Objects::ExternalAssetRepresentation do
  describe ".build_from" do
    it "builds with all URL fields" do
      obj = described_class.build_from(
        "pdf" => "https://example.com/doc.pdf",
        "slides" => "https://example.com/slides.pptx",
        "video" => "https://example.com/video"
      )
      expect(obj.pdf).to eq "https://example.com/doc.pdf"
      expect(obj.slides).to eq "https://example.com/slides.pptx"
      expect(obj.video).to eq "https://example.com/video"
    end

    it "defaults missing fields to empty string" do
      obj = described_class.build_from("pdf" => "https://example.com/doc.pdf")
      expect(obj.doc).to eq ""
      expect(obj.sheet).to eq ""
      expect(obj.form).to eq ""
      expect(obj.webpage).to eq ""
    end
  end

  describe "defaults" do
    subject { described_class.new }

    it "defaults all URL fields to empty string" do
      expect(subject.pdf).to eq ""
      expect(subject.doc).to eq ""
      expect(subject.slides).to eq ""
      expect(subject.sheet).to eq ""
      expect(subject.form).to eq ""
      expect(subject.video).to eq ""
      expect(subject.webpage).to eq ""
    end
  end
end
