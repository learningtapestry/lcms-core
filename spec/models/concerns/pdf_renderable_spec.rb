# frozen_string_literal: true

require "rails_helper"

describe PdfRenderable do
  # Test through Document — both Document and Material include this concern.
  subject(:record) { build_stubbed(:document, metadata: starting_metadata) }

  let(:starting_metadata) { {} }

  describe "#pdf_renderer" do
    context "when metadata['pdf_renderer'] is set" do
      let(:starting_metadata) { { "pdf_renderer" => "prince" } }

      it "returns the string value" do
        expect(record.pdf_renderer).to eq("prince")
      end
    end

    context "when metadata is empty" do
      it "returns nil" do
        expect(record.pdf_renderer).to be_nil
      end
    end

    context "when metadata['pdf_renderer'] is empty string" do
      let(:starting_metadata) { { "pdf_renderer" => "" } }

      it "returns nil" do
        expect(record.pdf_renderer).to be_nil
      end
    end

    context "when metadata is nil" do
      let(:starting_metadata) { nil }

      it "returns nil" do
        expect(record.pdf_renderer).to be_nil
      end
    end
  end

  describe "#pdf_renderer=" do
    it "stores under metadata['pdf_renderer']" do
      record.pdf_renderer = "prince"
      expect(record.metadata["pdf_renderer"]).to eq("prince")
    end

    it "coerces symbols to strings" do
      record.pdf_renderer = :prince
      expect(record.metadata["pdf_renderer"]).to eq("prince")
    end

    it "removes the key when set to nil" do
      record.metadata = { "pdf_renderer" => "prince", "other" => "keep" }
      record.pdf_renderer = nil
      expect(record.metadata).not_to have_key("pdf_renderer")
      expect(record.metadata["other"]).to eq("keep")
    end

    it "preserves other metadata keys" do
      record.metadata = { "subject" => "math" }
      record.pdf_renderer = "prince"
      expect(record.metadata).to include("subject" => "math", "pdf_renderer" => "prince")
    end
  end

  describe "#accessibility" do
    context "when set to a valid value" do
      let(:starting_metadata) { { "accessibility" => "pdf_ua" } }

      it "returns the string value" do
        expect(record.accessibility).to eq("pdf_ua")
      end
    end

    context "when unset" do
      it "returns nil" do
        expect(record.accessibility).to be_nil
      end
    end
  end

  describe "#accessibility=" do
    it "accepts :none, :tagged, :pdf_ua" do
      %w(none tagged pdf_ua).each do |level|
        record.accessibility = level
        expect(record.metadata["accessibility"]).to eq(level)
      end
    end

    it "accepts symbols" do
      record.accessibility = :pdf_ua
      expect(record.metadata["accessibility"]).to eq("pdf_ua")
    end

    it "rejects unknown levels" do
      expect { record.accessibility = "pdf_x" }
        .to raise_error(ArgumentError, /accessibility must be one of/)
    end

    it "removes the key when set to nil" do
      record.metadata = { "accessibility" => "pdf_ua" }
      record.accessibility = nil
      expect(record.metadata).not_to have_key("accessibility")
    end
  end

  describe "exporter resolution chain" do
    let(:document) { build_stubbed(:document, metadata: { "pdf_renderer" => "prince" }) }
    let(:presenter) { DocumentPresenter.new(document, content_type: :lesson) }

    it "presenter delegates pdf_renderer to model via SimpleDelegator" do
      expect(presenter.pdf_renderer).to eq("prince")
    end

    it "exporter resolves the renderer name from the model" do
      exporter = Exporters::Pdf::Document.new(presenter, {})
      expect(exporter.send(:renderer_name)).to eq(:prince)
    end

    it "falls through to registry default when document.pdf_renderer is nil" do
      bare = build_stubbed(:document, metadata: {})
      exporter = Exporters::Pdf::Document.new(DocumentPresenter.new(bare, content_type: :lesson), {})
      expect(exporter.send(:renderer_name)).to eq(Exporters::Pdf::RendererRegistry.default)
    end

    it "exporter resolves accessibility from the model" do
      doc = build_stubbed(:document, metadata: { "accessibility" => "pdf_ua" })
      exporter = Exporters::Pdf::Document.new(DocumentPresenter.new(doc, content_type: :lesson), {})
      expect(exporter.send(:accessibility_level)).to eq(:pdf_ua)
    end

    it "per-call options[:accessible_pdf] = true overrides record-level :none" do
      doc = build_stubbed(:document, metadata: { "accessibility" => "none" })
      exporter = Exporters::Pdf::Document.new(
        DocumentPresenter.new(doc, content_type: :lesson),
        { accessible_pdf: true }
      )
      expect(exporter.send(:accessibility_level)).to eq(:pdf_ua)
    end

    it "per-call options[:renderer] overrides record-level pdf_renderer" do
      exporter = Exporters::Pdf::Document.new(presenter, { renderer: :grover })
      expect(exporter.send(:renderer_name)).to eq(:grover)
    end
  end
end
