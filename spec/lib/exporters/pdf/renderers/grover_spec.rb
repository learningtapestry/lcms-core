# frozen_string_literal: true

require "rails_helper"

describe Exporters::Pdf::Renderers::Grover do
  subject(:renderer) { described_class.new }

  let(:grover_double) { instance_double(::Grover, to_pdf: pdf_bytes) }
  let(:pdf_bytes) { "%PDF-1.4\n…fake bytes…" }
  let(:html) { "<html><body>hi</body></html>" }

  before do
    allow(::Grover).to receive(:new).and_return(grover_double)
  end

  describe "protocol" do
    it "has identifier :grover" do
      expect(described_class.identifier).to eq(:grover)
    end

    it "advertises capabilities including :js_execution" do
      expect(described_class.capabilities).to include(:js_execution, :background_print, :landscape)
    end

    it "is available by default" do
      expect(described_class.available?).to be true
    end

    it "satisfies RendererRegistry's protocol verifier" do
      expect { Exporters::Pdf::RendererRegistry.register(described_class) }.not_to raise_error
      Exporters::Pdf::RendererRegistry.unregister(:grover)
    end
  end

  describe "#call" do
    let(:options) do
      Exporters::Pdf::RenderOptions.build(
        format: "Letter",
        orientation: "portrait",
        margin: { top: "0.5in", right: "1in", bottom: "0.5in", left: "0.5in" },
        dpi: 72,
        print_background: true,
        footer_html: "<footer>page</footer>"
      )
    end

    it "returns Grover's PDF bytes" do
      expect(renderer.call(html, options: options)).to eq(pdf_bytes)
    end

    it "passes the HTML to Grover" do
      renderer.call(html, options: options)
      expect(::Grover).to have_received(:new).with(html, anything)
    end

    it "translates portrait orientation to landscape: false" do
      renderer.call(html, options: options)
      expect(::Grover).to have_received(:new).with(html, hash_including(landscape: false))
    end

    it "translates landscape orientation to landscape: true" do
      landscape_opts = Exporters::Pdf::RenderOptions.build(orientation: "landscape", footer_html: "<f/>")
      renderer.call(html, options: landscape_opts)
      expect(::Grover).to have_received(:new).with(html, hash_including(landscape: true))
    end

    it "passes through format, margin, dpi, print_background" do
      renderer.call(html, options: options)
      expect(::Grover).to have_received(:new).with(
        html,
        hash_including(
          format: "Letter",
          margin: options.margin,
          dpi: 72,
          print_background: true
        )
      )
    end

    it "always sets prefer_css_page_size: false" do
      renderer.call(html, options: options)
      expect(::Grover).to have_received(:new).with(html, hash_including(prefer_css_page_size: false))
    end

    it "enables display_header_footer when footer_html is present" do
      renderer.call(html, options: options)
      expect(::Grover).to have_received(:new).with(html, hash_including(
        display_header_footer: true,
        footer_template: "<footer>page</footer>"
      ))
    end

    it "disables display_header_footer when both header_html and footer_html are nil" do
      bare = Exporters::Pdf::RenderOptions.build(header_html: nil, footer_html: nil)
      renderer.call(html, options: bare)
      expect(::Grover).to have_received(:new).with(html, hash_including(display_header_footer: false))
    end

    it "omits nil-valued translated keys" do
      no_margin = Exporters::Pdf::RenderOptions.build(margin: nil, dpi: nil, footer_html: "<f/>")
      renderer.call(html, options: no_margin)

      expect(::Grover).to have_received(:new) do |_html, args|
        expect(args).not_to have_key(:margin)
        expect(args).not_to have_key(:dpi)
      end
    end

    it "merges RenderOptions#extra over the translated hash" do
      extra_opts = Exporters::Pdf::RenderOptions.build(
        footer_html: "<f/>",
        extra: { wait_until: "networkidle2", scale: 1.5 }
      )
      renderer.call(html, options: extra_opts)
      expect(::Grover).to have_received(:new).with(html, hash_including(
        wait_until: "networkidle2",
        scale: 1.5
      ))
    end
  end
end
