# frozen_string_literal: true

require "rails_helper"

describe GdocPdf::Exporter do
  subject(:exporter) { described_class.new(source) }

  let(:fake_pdf) { "%PDF-1.4 fake bytes" }
  let(:raw_service) { instance_double(Google::Apis::DriveV3::DriveService) }
  let(:drive) { instance_double(Google::DriveService, service: raw_service) }

  # Drive's export_file streams bytes into the supplied download_dest IO.
  def stub_export(returning: fake_pdf)
    allow(raw_service).to receive(:export_file) do |_file_id, _mime, download_dest:|
      download_dest.write(returning)
    end
  end

  before { allow(Google::DriveService).to receive(:build).and_return(drive) }

  describe ".credentials_present?" do
    it "is true when credentials resolve" do
      cli = instance_double(Lt::Google::Api::Auth::Cli, credentials: Object.new)
      allow(Lt::Google::Api::Auth::Cli).to receive(:new).and_return(cli)
      expect(described_class.credentials_present?).to be true
    end

    it "is false when credential resolution raises" do
      allow(Lt::Google::Api::Auth::Cli).to receive(:new).and_raise(StandardError, "no creds")
      expect(described_class.credentials_present?).to be false
    end
  end

  describe "#to_pdf — reuse path" do
    let(:source) do
      double(
        "DocumentPresenter",
        content_type: :unit_bundle,
        links: { "unit_bundle" => { "gdoc" => { "url" => "https://drive.google.com/open?id=REUSED123" } } }
      )
    end

    it "exports the already-linked Google Doc to PDF and returns the bytes" do
      stub_export
      expect(exporter.to_pdf).to eq(fake_pdf)
      expect(raw_service).to have_received(:export_file)
        .with("REUSED123", "application/pdf", download_dest: instance_of(StringIO))
    end

    it "does not generate a new Google Doc when one is already linked" do
      stub_export
      expect(Exporters::Gdoc::Document).not_to receive(:new)
      exporter.to_pdf
    end
  end

  describe "#to_pdf — generate path" do
    let(:source) do
      double("DocumentPresenter", content_type: :unit_bundle, links: {})
    end
    let(:gdoc) { instance_double(Exporters::Gdoc::Document) }

    before do
      allow(Exporters::Gdoc::Document).to receive(:new).with(source, {}).and_return(gdoc)
      allow(gdoc).to receive(:export).and_return(gdoc)
      allow(gdoc).to receive(:url).and_return("https://drive.google.com/open?id=GENERATED456")
    end

    it "generates the Google Doc through the full pipeline, then exports it" do
      stub_export
      expect(exporter.to_pdf).to eq(fake_pdf)
      expect(Exporters::Gdoc::Document).to have_received(:new).with(source, {})
      expect(raw_service).to have_received(:export_file)
        .with("GENERATED456", "application/pdf", download_dest: instance_of(StringIO))
    end

    it "raises ExportError when no Google Doc can be resolved" do
      allow(gdoc).to receive(:url).and_return("")
      expect { exporter.to_pdf }.to raise_error(described_class::ExportError, /no Google Doc available/)
    end
  end

  describe "#to_pdf — generate path (Material)" do
    let(:material) { double("Material", links: {}) }
    let(:source) { MaterialPresenter.new(material, content_type: :unit_bundle) }
    let(:gdoc) { instance_double(Exporters::Gdoc::Material) }

    before do
      allow(Exporters::Gdoc::Document).to receive(:new)
      allow(Exporters::Gdoc::Material).to receive(:new).and_return(gdoc)
      allow(gdoc).to receive(:export).and_return(gdoc)
      allow(gdoc).to receive(:url).and_return("https://drive.google.com/open?id=MAT789")
    end

    it "routes Material presenters to Gdoc::Material and exports the generated doc" do
      stub_export
      expect(exporter.to_pdf).to eq(fake_pdf)
      expect(Exporters::Gdoc::Material).to have_received(:new).with(source, {})
      expect(Exporters::Gdoc::Document).not_to have_received(:new)
      expect(raw_service).to have_received(:export_file)
        .with("MAT789", "application/pdf", download_dest: instance_of(StringIO))
    end
  end

  describe "#to_pdf — export retries" do
    let(:source) do
      double(
        "DocumentPresenter",
        content_type: :unit_bundle,
        links: { "unit_bundle" => { "gdoc" => { "url" => "https://drive.google.com/open?id=REUSED123" } } }
      )
    end

    before { stub_const("#{described_class}::EXPORT_BASE_INTERVAL", 0) }

    it "uses a fresh buffer per attempt so a retried export is not corrupted by partial bytes" do
      attempts = 0
      allow(raw_service).to receive(:export_file) do |_id, _mime, download_dest:|
        attempts += 1
        download_dest.write("%PDF-clean")
        raise Google::Apis::RateLimitError, "rate limited" if attempts == 1
      end

      expect(exporter.to_pdf).to eq("%PDF-clean")
      expect(attempts).to eq(2)
    end

    it "raises ExportError after exhausting retries on persistent rate limiting" do
      stub_const("#{described_class}::EXPORT_TRIES", 2)
      allow(raw_service).to receive(:export_file).and_raise(Google::Apis::RateLimitError, "always")

      expect { exporter.to_pdf }.to raise_error(described_class::ExportError, /always/)
      expect(raw_service).to have_received(:export_file).twice
    end
  end

  describe "#to_pdf — unresolvable gdoc link" do
    let(:gdoc) { instance_double(Exporters::Gdoc::Document, url: "") }

    before do
      allow(Exporters::Gdoc::Document).to receive(:new).and_return(gdoc)
      allow(gdoc).to receive(:export).and_return(gdoc)
    end

    {
      "nil links" => nil,
      "missing content_type key" => { "other" => {} },
      "nil gdoc entry" => { "unit_bundle" => { "gdoc" => nil } },
      "blank url in gdoc entry" => { "unit_bundle" => { "gdoc" => { "url" => "" } } }
    }.each do |desc, links_value|
      context "with #{desc}" do
        let(:source) { double("DocumentPresenter", content_type: :unit_bundle, links: links_value) }

        it "resolves the link without crashing and raises ExportError when nothing is available" do
          expect { exporter.to_pdf }.to raise_error(described_class::ExportError, /no Google Doc available/)
        end
      end
    end
  end

  describe "#to_pdf — Drive failures" do
    let(:source) do
      double(
        "DocumentPresenter",
        content_type: :unit_bundle,
        links: { "unit_bundle" => { "gdoc" => { "url" => "https://drive.google.com/open?id=REUSED123" } } }
      )
    end

    it "wraps Google::Apis::Error as ExportError" do
      allow(raw_service).to receive(:export_file).and_raise(Google::Apis::Error, "drive blew up")
      expect { exporter.to_pdf }.to raise_error(described_class::ExportError, /drive blew up/)
    end
  end

  describe "Google Doc id extraction" do
    let(:source) { double("DocumentPresenter", content_type: :unit_bundle, links: links) }

    {
      "https://drive.google.com/open?id=ABC123" => "ABC123",
      "https://docs.google.com/document/d/XYZ789/edit" => "XYZ789",
      "https://drive.google.com/file/d/QQQ000/view?usp=sharing" => "QQQ000",
      "https://docs.google.com/document/d/QRY111?usp=sharing" => "QRY111"
    }.each do |url, expected_id|
      context "with URL #{url}" do
        let(:links) { { "unit_bundle" => { "gdoc" => { "url" => url } } } }

        it "extracts #{expected_id}" do
          stub_export
          exporter.to_pdf
          expect(raw_service).to have_received(:export_file).with(expected_id, "application/pdf", download_dest: anything)
        end
      end
    end

    context "with a legacy plain-string gdoc link" do
      let(:links) { { "unit_bundle" => { "gdoc" => "https://drive.google.com/open?id=LEGACY555" } } }

      it "extracts the id from the bare URL string" do
        stub_export
        exporter.to_pdf
        expect(raw_service).to have_received(:export_file).with("LEGACY555", "application/pdf", download_dest: anything)
      end
    end
  end
end
