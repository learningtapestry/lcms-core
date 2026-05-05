# frozen_string_literal: true

require "rails_helper"

describe PrincePdf::Renderer do
  subject(:renderer) { described_class.new }

  let(:html) { "<html><body><h1>Hi</h1></body></html>" }
  let(:options) do
    Exporters::Pdf::RenderOptions.build(
      orientation: "portrait",
      margin: { top: "0.5in", right: "1in", bottom: "0.5in", left: "0.5in" },
      accessibility: :pdf_ua
    )
  end
  let(:fake_pdf) { "%PDF-1.4 fake bytes" }

  describe "protocol" do
    it "has identifier :prince" do
      expect(described_class.identifier).to eq(:prince)
    end

    it "advertises :pdf_ua and :tagged_pdf capabilities" do
      expect(described_class.capabilities).to include(:pdf_ua, :tagged_pdf)
    end

    it "uses the pdf_prince layout" do
      expect(described_class.layout_name).to eq("pdf_prince")
    end

    it "delegates available? to Executable.present?" do
      allow(PrincePdf::Executable).to receive(:present?).and_return(true)
      expect(described_class.available?).to be true

      allow(PrincePdf::Executable).to receive(:present?).and_return(false)
      expect(described_class.available?).to be false
    end

    it "satisfies RendererRegistry's protocol verifier" do
      expect { Exporters::Pdf::RendererRegistry.register(described_class) }.not_to raise_error
    ensure
      Exporters::Pdf::RendererRegistry.unregister(:prince)
      # Re-register the host's default to keep state stable for other specs
      Exporters::Pdf::RendererRegistry.register(Exporters::Pdf::Renderers::Grover) \
        unless Exporters::Pdf::RendererRegistry.all.include?(:grover)
    end

    it "is registered with :pdf_ua capability so the registry's gate accepts it" do
      Exporters::Pdf::RendererRegistry.register(described_class)
      allow(PrincePdf::Executable).to receive(:present?).and_return(true)

      expect { Exporters::Pdf::RendererRegistry.fetch_for(identifier: :prince, accessibility: :pdf_ua) }
        .not_to raise_error
    ensure
      Exporters::Pdf::RendererRegistry.unregister(:prince)
    end
  end

  describe "#call" do
    before do
      allow(PrincePdf::Executable).to receive(:run).and_return(fake_pdf)
    end

    it "returns the bytes from Executable.run" do
      expect(renderer.call(html, options: options)).to eq(fake_pdf)
    end

    it "passes the HTML on stdin and translated args to Executable.run" do
      renderer.call(html, options: options)
      expect(PrincePdf::Executable).to have_received(:run) do |args, stdin:|
        expect(args).to be_an(Array)
        expect(args).to include("--javascript", "--http-timeout=30", "--pdf-profile=PDF/UA-1")
        expect(stdin).to eq(html)
      end
    end

    it "wraps NonZeroExit as RendererRegistry::RenderError" do
      allow(PrincePdf::Executable).to receive(:run)
        .and_raise(PrincePdf::Executable::NonZeroExit, "prince: error: boom")

      expect { renderer.call(html, options: options) }
        .to raise_error(Exporters::Pdf::RendererRegistry::RenderError, /PrinceXML failed.*boom/)
    end
  end
end
