# frozen_string_literal: true

require "rails_helper"

describe MaterialGdocJob do
  describe "class configuration" do
    it "has LINK_KEY constant" do
      expect(described_class::LINK_KEY).to eq "gdoc"
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
    let(:gdoc_url) { "https://drive.google.com/open?id=xyz789" }
    let(:presenter) do
      double("MaterialPresenter").tap do |p|
        allow(p).to receive(:with_lock).and_yield
        allow(p).to receive(:reload).and_return(p)
        allow(p).to receive(:links).and_return({})
        allow(p).to receive(:preview_links).and_return({})
        allow(p).to receive(:update)
      end
    end
    let(:exporter) do
      double("Exporters::Gdoc::Material", url: gdoc_url)
    end

    before do
      allow(MaterialPresenter).to receive(:new).and_return(presenter)
      allow(Exporters::Gdoc::Material).to receive(:new).and_return(exporter)
      allow(exporter).to receive(:export).and_return(exporter)
    end

    it "creates a MaterialPresenter with content_type" do
      expect(MaterialPresenter).to receive(:new)
        .with(material, content_type: content_type)
        .and_return(presenter)

      described_class.new.perform(material.id, options)
    end

    it "exports the material to Google Docs" do
      expect(Exporters::Gdoc::Material).to receive(:new)
        .with(presenter, options.with_indifferent_access)
        .and_return(exporter)
      expect(exporter).to receive(:export).and_return(exporter)

      described_class.new.perform(material.id, options)
    end

    it "updates material links with GDoc URL" do
      expect(presenter).to receive(:update) do |args|
        expect(args[:links]).to include(content_type.to_s)
        expect(args[:links][content_type.to_s]["gdoc"]).to include(url: gdoc_url)
        expect(args[:links][content_type.to_s]["gdoc"][:pages]).to eq(-1)
      end

      described_class.new.perform(material.id, options)
    end

    it "includes timestamp in links data" do
      expect(presenter).to receive(:update) do |args|
        expect(args[:links][content_type.to_s]["gdoc"][:timestamp]).to be_an(Integer)
        expect(args[:links][content_type.to_s]["gdoc"][:timestamp]).to be > 0
      end

      described_class.new.perform(material.id, options)
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
    end

    context "when preview option is false" do
      let(:options) { { content_type: content_type, preview: false } }

      it "updates links instead of preview_links" do
        expect(presenter).to receive(:update) do |args|
          expect(args).to have_key(:links)
          expect(args).not_to have_key(:preview_links)
        end

        described_class.new.perform(material.id, options)
      end
    end

    context "when folder_id option is provided" do
      let(:options) { { content_type: content_type, folder_id: "folder_123" } }

      it "passes folder_id to exporter" do
        expect(Exporters::Gdoc::Material).to receive(:new)
          .with(presenter, hash_including(folder_id: "folder_123"))
          .and_return(exporter)

        described_class.new.perform(material.id, options)
      end
    end
  end
end
