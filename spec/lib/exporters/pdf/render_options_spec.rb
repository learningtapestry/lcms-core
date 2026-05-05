# frozen_string_literal: true

require "rails_helper"

describe Exporters::Pdf::RenderOptions do
  describe ".build" do
    it "applies defaults for unspecified fields" do
      opts = described_class.build

      expect(opts.format).to eq("Letter")
      expect(opts.orientation).to eq("portrait")
      expect(opts.print_background).to be true
      expect(opts.accessibility).to eq(:none)
      expect(opts.show_header).to be true
      expect(opts.show_name_date).to be false
      expect(opts.metadata).to eq({})
      expect(opts.extra).to eq({})
    end

    it "accepts overrides" do
      opts = described_class.build(
        format: "A4",
        orientation: "landscape",
        margin: { top: "1in", right: "0.5in", bottom: "1in", left: "0.5in" },
        accessibility: :pdf_ua,
        show_header: false,
        show_name_date: true
      )

      expect(opts.format).to eq("A4")
      expect(opts.orientation).to eq("landscape")
      expect(opts.margin[:top]).to eq("1in")
      expect(opts.accessibility).to eq(:pdf_ua)
      expect(opts.show_header).to be false
      expect(opts.show_name_date).to be true
    end

    it "rejects unknown accessibility levels" do
      expect { described_class.build(accessibility: :pdf_x) }
        .to raise_error(ArgumentError, /accessibility must be one of/)
    end

    it "rejects unknown orientations" do
      expect { described_class.build(orientation: "diagonal") }
        .to raise_error(ArgumentError, /orientation must be one of/)
    end

    it "normalizes mixed-case orientation to lowercase" do
      expect(described_class.build(orientation: "Landscape").orientation).to eq("landscape")
      expect(described_class.build(orientation: "PORTRAIT").orientation).to eq("portrait")
    end
  end

  describe "#landscape? / #portrait?" do
    it "is portrait by default" do
      opts = described_class.build
      expect(opts.portrait?).to be true
      expect(opts.landscape?).to be false
    end

    it "reflects landscape orientation" do
      opts = described_class.build(orientation: "landscape")
      expect(opts.landscape?).to be true
      expect(opts.portrait?).to be false
    end
  end

  describe "#accessible?" do
    it "is false when accessibility is :none" do
      expect(described_class.build(accessibility: :none).accessible?).to be false
    end

    it "is true for :tagged" do
      expect(described_class.build(accessibility: :tagged).accessible?).to be true
    end

    it "is true for :pdf_ua" do
      expect(described_class.build(accessibility: :pdf_ua).accessible?).to be true
    end
  end

  describe "value semantics" do
    it "treats two builds with the same args as equal" do
      a = described_class.build(format: "A4")
      b = described_class.build(format: "A4")
      expect(a).to eq(b)
    end

    it "is frozen by Data semantics" do
      opts = described_class.build
      expect { opts.instance_variable_set(:@format, "A4") }.to raise_error(FrozenError)
    end
  end
end
