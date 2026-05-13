# frozen_string_literal: true

require "rails_helper"

describe Exporters::Pdf::Base do
  let(:exporter_class) do
    Class.new(described_class) do
      private

      def base_path(name)
        File.join("dummy", name)
      end
    end
  end

  let(:render_options) { Exporters::Pdf::RenderOptions.build }
  let(:document) do
    double(
      "DocumentLike",
      render_options: render_options,
      pdf_renderer: nil,
      accessibility: nil
    )
  end
  let(:exporter) { exporter_class.new(document, {}) }

  describe "#export" do
    it "falls back to the default pdf layout when the renderer omits .layout_name" do
      renderer = Class.new do
        def call(html, options:)
          "%PDF-1.4\n#{html}"
        end
      end.new

      allow(Exporters::Pdf::RendererRegistry).to receive(:fetch_for).and_return(renderer)
      allow(exporter).to receive(:render_template)
        .with(File.join("dummy", "_footer"), layout: "pdf_plain")
        .and_return("<footer/>")
      expect(exporter).to receive(:render_template)
        .with(File.join("dummy", "show"), layout: "pdf")
        .and_return("<html/>")

      expect(exporter.export).to start_with("%PDF-1.4")
    end
  end
end
