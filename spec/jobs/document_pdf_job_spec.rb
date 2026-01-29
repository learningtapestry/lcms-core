# frozen_string_literal: true

require "rails_helper"

describe DocumentPdfJob do
  describe "class configuration" do
    it "has LINK_KEY constant" do
      expect(described_class::LINK_KEY).to eq "pdf"
    end

    it "includes DocumentRescuableJob" do
      expect(described_class.ancestors).to include(DocumentRescuableJob)
    end

    it "includes ResqueJob" do
      expect(described_class.ancestors).to include(ResqueJob)
    end
  end

  describe "#perform" do
    let(:document) { create(:document) }
    let(:content_type) { :unit_bundle }
    let(:options) { { content_type: content_type } }
    let(:pdf_content) { "PDF binary content" }
    let(:s3_url) { "https://s3.example.com/documents/test.pdf" }
    let(:presenter) do
      double("DocumentPresenter", pdf_filename: "test.pdf").tap do |p|
        allow(p).to receive(:with_lock).and_yield
        allow(p).to receive(:reload).and_return(p)
        allow(p).to receive(:links).and_return({})
        allow(p).to receive(:update)
      end
    end
    let(:exporter) do
      double("Exporters::Pdf::Document").tap do |e|
        allow(e).to receive(:export).and_return(pdf_content)
      end
    end

    before do
      allow(DocumentPresenter).to receive(:new).and_return(presenter)
      allow(Exporters::Pdf::Document).to receive(:new).and_return(exporter)
      allow(S3Service).to receive(:upload).and_return(s3_url)
    end

    it "creates a DocumentPresenter with content_type" do
      expect(DocumentPresenter).to receive(:new)
        .with(document, content_type: content_type)
        .and_return(presenter)

      described_class.new.perform(document.id, options)
    end

    it "exports the document to PDF" do
      expect(Exporters::Pdf::Document).to receive(:new)
        .with(presenter, options)
        .and_return(exporter)
      expect(exporter).to receive(:export).and_return(pdf_content)

      described_class.new.perform(document.id, options)
    end

    it "uploads PDF to S3" do
      expect(S3Service).to receive(:upload)
        .with("documents/test.pdf", pdf_content, content_type: "application/pdf")
        .and_return(s3_url)

      described_class.new.perform(document.id, options)
    end

    it "updates document links with PDF URL" do
      expect(presenter).to receive(:update) do |args|
        expect(args[:links]).to include(content_type.to_s)
        expect(args[:links][content_type.to_s]["pdf"]).to include(url: s3_url)
      end

      described_class.new.perform(document.id, options)
    end
  end
end
