# frozen_string_literal: true

require "rails_helper"

describe GdocPdf::Renderer do
  it_behaves_like "a PDF renderer"

  subject(:renderer) { described_class.new }

  let(:html) { "<html><body><h1>ignored</h1></body></html>" }
  let(:source) { instance_double(DocumentPresenter) }
  let(:options) { Exporters::Pdf::RenderOptions.build(source: source) }
  let(:fake_pdf) { "%PDF-1.4 fake bytes" }

  describe "protocol" do
    it "has identifier :gdoc_pdf" do
      expect(described_class.identifier).to eq(:gdoc_pdf)
    end

    it "advertises no accessibility capabilities" do
      expect(described_class.capabilities).to be_empty
    end

    it "delegates available? to Exporter.credentials_present?" do
      allow(GdocPdf::Exporter).to receive(:credentials_present?).and_return(true)
      expect(described_class.available?).to be true

      allow(GdocPdf::Exporter).to receive(:credentials_present?).and_return(false)
      expect(described_class.available?).to be false
    end

    it "satisfies RendererRegistry's protocol verifier" do
      Exporters::Pdf::RendererRegistry.unregister(:gdoc_pdf)
      expect { Exporters::Pdf::RendererRegistry.register(described_class) }.not_to raise_error
    end

    it "is refused for accessibility requests (no tagged/pdf_ua capability)" do
      # Isolate the capability gate from the availability gate: fetch_for checks
      # availability first, so without this stub the host's missing Drive
      # credentials would raise Unavailable before the capability check is reached.
      allow(GdocPdf::Exporter).to receive(:credentials_present?).and_return(true)
      expect { Exporters::Pdf::RendererRegistry.fetch_for(identifier: :gdoc_pdf, accessibility: :pdf_ua) }
        .to raise_error(Exporters::Pdf::RendererRegistry::UnsupportedCapability)
    end
  end

  describe "#call" do
    let(:exporter) { instance_double(GdocPdf::Exporter) }

    before do
      allow(GdocPdf::Exporter).to receive(:new).with(source, options).and_return(exporter)
      allow(exporter).to receive(:to_pdf).and_return(fake_pdf)
    end

    it "ignores the HTML and returns the bytes from Exporter#to_pdf" do
      expect(renderer.call(html, options: options)).to eq(fake_pdf)
    end

    it "passes the source presenter from options to the Exporter" do
      renderer.call(html, options: options)
      expect(GdocPdf::Exporter).to have_received(:new).with(source, options)
    end

    it "raises RenderError when options.source is missing" do
      no_source = Exporters::Pdf::RenderOptions.build
      expect { renderer.call(html, options: no_source) }
        .to raise_error(Exporters::Pdf::RendererRegistry::RenderError, /requires options\.source/)
    end

    it "wraps Exporter::ExportError as RendererRegistry::RenderError" do
      allow(exporter).to receive(:to_pdf).and_raise(GdocPdf::Exporter::ExportError, "boom")
      expect { renderer.call(html, options: options) }
        .to raise_error(Exporters::Pdf::RendererRegistry::RenderError, /Gdoc PDF export failed.*boom/)
    end
  end
end
