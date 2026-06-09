# frozen_string_literal: true

require "rails_helper"

describe PrincePdf::OptionsTranslator do
  subject(:args) { described_class.new(options).to_args }

  let(:options) do
    Exporters::Pdf::RenderOptions.build(
      orientation: "portrait",
      margin: { top: "0.5in", right: "1in", bottom: "0.5in", left: "0.5in" },
      accessibility: :pdf_ua
    )
  end

  describe "command shape" do
    it "starts with stdin/stdout flags" do
      expect(args[0]).to eq("-")
      expect(args[1]).to eq("--output=-")
    end

    it "always enables JavaScript" do
      expect(args).to include("--javascript")
    end

    it "always sets http-timeout" do
      expect(args).to include("--http-timeout=30")
    end

    it "loads the base tagging stylesheet" do
      base = args.find { |a| a.end_with?("prince_xml.css") && a.start_with?("--style=") }
      expect(base).not_to be_nil
    end

    it "loads the orientation-specific stylesheet" do
      orient = args.find { |a| a.end_with?("prince_xml_portrait.css") && a.start_with?("--style=") }
      expect(orient).not_to be_nil
    end

    it "loads the JS hook via --script=" do
      script = args.find { |a| a.start_with?("--script=") && a.end_with?("prince_xml.js") }
      expect(script).not_to be_nil
    end
  end

  describe "license" do
    it "omits --license-file when env unset" do
      original = ENV["PRINCE_LICENSE_PATH"]
      ENV.delete("PRINCE_LICENSE_PATH")
      expect(args.any? { |a| a.start_with?("--license-file=") }).to be false
    ensure
      ENV["PRINCE_LICENSE_PATH"] = original
    end

    it "includes --license-file when env set" do
      original = ENV["PRINCE_LICENSE_PATH"]
      ENV["PRINCE_LICENSE_PATH"] = "/etc/prince/license.dat"
      expect(args).to include("--license-file=/etc/prince/license.dat")
    ensure
      ENV["PRINCE_LICENSE_PATH"] = original
    end
  end

  describe "margin" do
    it "joins top/right/bottom/left into a single quoted arg" do
      margin_arg = args.find { |a| a.start_with?("--page-margin=") }
      expect(margin_arg).to eq('--page-margin="0.5in 1in 0.5in 0.5in"')
    end

    it "omits --page-margin when margin is nil" do
      no_margin = Exporters::Pdf::RenderOptions.build(orientation: "portrait", margin: nil)
      out = described_class.new(no_margin).to_args
      expect(out.any? { |a| a.start_with?("--page-margin=") }).to be false
    end
  end

  describe "accessibility" do
    it "adds --pdf-profile=PDF/UA-1 for :pdf_ua" do
      pdf_ua = Exporters::Pdf::RenderOptions.build(accessibility: :pdf_ua, orientation: "portrait")
      expect(described_class.new(pdf_ua).to_args).to include("--pdf-profile=PDF/UA-1")
    end

    it "adds --tagged-pdf for :tagged" do
      tagged = Exporters::Pdf::RenderOptions.build(accessibility: :tagged, orientation: "portrait")
      expect(described_class.new(tagged).to_args).to include("--tagged-pdf")
    end

    it "omits accessibility flags for :none" do
      none = Exporters::Pdf::RenderOptions.build(accessibility: :none, orientation: "portrait")
      out = described_class.new(none).to_args
      expect(out.any? { |a| a.include?("--pdf-profile=") || a == "--tagged-pdf" }).to be false
    end
  end

  describe "orientation guard" do
    # RenderOptions.build validates orientation, but RenderOptions.new bypasses
    # that path. The translator must defend itself so a poisoned value cannot
    # be interpolated into a stylesheet path that lands on the prince CLI.
    it "raises ArgumentError when orientation is not in ALLOWED_ORIENTATION" do
      poisoned = Exporters::Pdf::RenderOptions.new(
        format: "Letter",
        orientation: "../../../etc/passwd",
        margin: nil,
        dpi: nil,
        image_dpi: nil,
        print_background: true,
        header_html: nil,
        footer_html: nil,
        metadata: {},
        accessibility: :none,
        show_header: true,
        show_name_date: false,
        padding: nil,
        extra: {}
      )

      expect { described_class.new(poisoned).to_args }
        .to raise_error(ArgumentError, /invalid orientation/)
    end
  end
end
