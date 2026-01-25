# frozen_string_literal: true

require "rails_helper"

describe DocumentGdocJob do
  describe "class configuration" do
    it "has LINK_KEY constant" do
      expect(described_class::LINK_KEY).to eq "gdoc"
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
    let(:gdoc_url) { "https://drive.google.com/open?id=abc123" }
    let(:presenter) do
      double("DocumentPresenter").tap do |p|
        allow(p).to receive(:with_lock).and_yield
        allow(p).to receive(:reload).and_return(p)
        allow(p).to receive(:links).and_return({})
        allow(p).to receive(:preview_links).and_return({})
        allow(p).to receive(:update)
      end
    end
    let(:exporter) do
      double("Exporters::Gdoc::Document", url: gdoc_url)
    end

    before do
      allow(DocumentPresenter).to receive(:new).and_return(presenter)
      allow(Exporters::Gdoc::Document).to receive(:new).and_return(exporter)
      allow(exporter).to receive(:export).and_return(exporter)
    end

    it "creates a DocumentPresenter with content_type" do
      expect(DocumentPresenter).to receive(:new)
        .with(document, content_type: content_type)
        .and_return(presenter)

      described_class.new.perform(document.id, options)
    end

    it "exports the document to Google Docs" do
      expect(Exporters::Gdoc::Document).to receive(:new)
        .with(presenter, options.with_indifferent_access)
        .and_return(exporter)
      expect(exporter).to receive(:export).and_return(exporter)

      described_class.new.perform(document.id, options)
    end

    it "updates document links with GDoc URL" do
      expect(presenter).to receive(:update) do |args|
        expect(args[:links]).to include(content_type.to_s)
        expect(args[:links][content_type.to_s]["gdoc"]).to include(url: gdoc_url)
        expect(args[:links][content_type.to_s]["gdoc"][:pages]).to eq(-1)
      end

      described_class.new.perform(document.id, options)
    end

    it "includes timestamp in links data" do
      expect(presenter).to receive(:update) do |args|
        expect(args[:links][content_type.to_s]["gdoc"][:timestamp]).to be_an(Integer)
        expect(args[:links][content_type.to_s]["gdoc"][:timestamp]).to be > 0
      end

      described_class.new.perform(document.id, options)
    end

    context "when preview option is true" do
      let(:options) { { content_type: content_type, preview: true } }

      it "updates preview_links instead of links" do
        expect(presenter).to receive(:update) do |args|
          expect(args).to have_key(:preview_links)
          expect(args).not_to have_key(:links)
        end

        described_class.new.perform(document.id, options)
      end
    end

    context "when preview option is false" do
      let(:options) { { content_type: content_type, preview: false } }

      it "updates links instead of preview_links" do
        expect(presenter).to receive(:update) do |args|
          expect(args).to have_key(:links)
          expect(args).not_to have_key(:preview_links)
        end

        described_class.new.perform(document.id, options)
      end
    end
  end
end
