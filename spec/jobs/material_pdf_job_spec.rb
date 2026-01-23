# frozen_string_literal: true

require "rails_helper"

describe MaterialPdfJob do
  describe "class configuration" do
    it "has LINK_KEY constant" do
      expect(described_class::LINK_KEY).to eq "pdf"
    end

    it "includes MaterialRescuableJob" do
      expect(described_class.ancestors).to include(MaterialRescuableJob)
    end

    it "includes ResqueJob" do
      expect(described_class.ancestors).to include(ResqueJob)
    end
  end

  describe "#perform" do
    let(:material) { create(:material) }
    let(:content_type) { :unit_bundle }
    let(:options) { { content_type: content_type } }
    let(:pdf_content) { "PDF binary content" }
    let(:thumb_content) { "Thumbnail binary content" }
    let(:pdf_url) { "https://s3.example.com/materials/test.pdf" }
    let(:thumb_url) { "https://s3.example.com/materials/test.jpg" }
    let(:presenter) do
      double("MaterialPresenter",
        pdf_filename: "test.pdf",
        base_filename: "test"
      ).tap do |p|
        allow(p).to receive(:with_lock).and_yield
        allow(p).to receive(:reload).and_return(p)
        allow(p).to receive(:links).and_return({})
        allow(p).to receive(:preview_links).and_return({})
        allow(p).to receive(:update)
      end
    end
    let(:pdf_exporter) do
      double("Exporters::Pdf::Material").tap do |e|
        allow(e).to receive(:export).and_return(pdf_content)
      end
    end
    let(:thumb_exporter) do
      double("Exporters::Thumbnail").tap do |e|
        allow(e).to receive(:export).and_return(thumb_content)
      end
    end

    before do
      allow(MaterialPresenter).to receive(:new).and_return(presenter)
      allow(Exporters::Pdf::Material).to receive(:new).and_return(pdf_exporter)
      allow(Exporters::Thumbnail).to receive(:new).and_return(thumb_exporter)
      allow(S3Service).to receive(:upload).and_return(pdf_url, thumb_url)
      allow(CombinePDF).to receive(:parse).and_return(double(pages: [1, 2, 3]))
    end

    it "creates a MaterialPresenter with content_type" do
      expect(MaterialPresenter).to receive(:new)
        .with(material, content_type: content_type)
        .and_return(presenter)

      described_class.new.perform(material.id, options)
    end

    it "exports the material to PDF" do
      expect(Exporters::Pdf::Material).to receive(:new)
        .with(presenter, options.with_indifferent_access)
        .and_return(pdf_exporter)
      expect(pdf_exporter).to receive(:export).and_return(pdf_content)

      described_class.new.perform(material.id, options)
    end

    it "generates a thumbnail from the PDF" do
      expect(Exporters::Thumbnail).to receive(:new)
        .with(pdf_content)
        .and_return(thumb_exporter)
      expect(thumb_exporter).to receive(:export).and_return(thumb_content)

      described_class.new.perform(material.id, options)
    end

    it "uploads PDF to S3" do
      expect(S3Service).to receive(:upload)
        .with("materials/test.pdf", pdf_content, content_type: "application/pdf")

      described_class.new.perform(material.id, options)
    end

    it "uploads thumbnail to S3" do
      expect(S3Service).to receive(:upload)
        .with("materials/test.jpg", thumb_content, content_type: "image/jpeg")

      described_class.new.perform(material.id, options)
    end

    it "calculates page count from PDF" do
      pdf_parser = double(pages: [1, 2, 3])
      expect(CombinePDF).to receive(:parse).with(pdf_content).and_return(pdf_parser)

      described_class.new.perform(material.id, options)
    end

    it "updates material links with PDF and thumbnail URLs" do
      expect(presenter).to receive(:update) do |args|
        data = args[:links][content_type.to_s]["pdf"]
        expect(data[:url]).to eq pdf_url
        expect(data[:thumb_url]).to eq thumb_url
        expect(data[:pages]).to eq 3
      end

      described_class.new.perform(material.id, options)
    end

    context "when folder option is provided" do
      let(:options) { { content_type: content_type, folder: "custom/folder" } }

      it "uses the folder in S3 path" do
        expect(S3Service).to receive(:upload)
          .with("custom/folder/materials/test.pdf", pdf_content, content_type: "application/pdf")
        expect(S3Service).to receive(:upload)
          .with("custom/folder/materials/test.jpg", thumb_content, content_type: "image/jpeg")

        described_class.new.perform(material.id, options)
      end
    end

    context "when preview option is true" do
      let(:options) { { content_type: content_type, preview: true } }

      it "updates preview_links instead of links" do
        expect(presenter).to receive(:update) do |args|
          expect(args).to have_key(:preview_links)
          expect(args).not_to have_key(:links)
        end

        described_class.new.perform(material.id, options)
      end

      it "does not calculate page count" do
        expect(CombinePDF).not_to receive(:parse)

        described_class.new.perform(material.id, options)
      end
    end
  end
end
