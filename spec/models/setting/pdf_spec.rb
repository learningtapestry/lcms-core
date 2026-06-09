# frozen_string_literal: true

require "rails_helper"

RSpec.describe Setting::Pdf do
  def build_model(submitted, stored: Settings::DEFAULTS[:pdf].deep_stringify_keys)
    described_class.new(stored: stored, submitted: submitted)
  end

  describe "the shipped defaults" do
    it "are valid against the schema" do
      expect(described_class.new).to be_valid
    end
  end

  describe "casting" do
    it "casts known integer and boolean fields to their declared types" do
      model = build_model({ "default" => { "dpi" => "80", "header" => "0", "name_date" => "1" } })

      expect(model.to_h.dig("default", "dpi")).to eq(80)
      expect(model.to_h.dig("default", "header")).to be(false)
      expect(model.to_h.dig("default", "name_date")).to be(true)
    end

    it "keeps length fields as strings" do
      model = build_model({ "default" => { "margin" => { "top" => "1in" } } })

      expect(model.to_h.dig("default", "margin", "top")).to eq("1in")
    end
  end

  describe "validation" do
    it "rejects a non-positive integer" do
      model = build_model({ "default" => { "dpi" => "-5" } })

      expect(model).not_to be_valid
      expect(model.errors["default.dpi"].first).to include("at least 1")
    end

    it "rejects a non-numeric integer field" do
      model = build_model({ "default" => { "dpi" => "abc" } })

      expect(model).not_to be_valid
      expect(model.errors["default.dpi"].first).to include("whole number")
    end

    it "rejects an orientation outside the allowed list" do
      model = build_model({ "default" => { "orientation" => "sideways" } })

      expect(model).not_to be_valid
      expect(model.errors["default.orientation"].first).to include("portrait, landscape")
    end

    it "rejects a malformed length" do
      model = build_model({ "default" => { "margin" => { "top" => "0.5banana" } } })

      expect(model).not_to be_valid
      expect(model.errors["default.margin.top"].first).to include("length")
    end

    it "allows partial content-type blocks (absent fields are not required)" do
      # handout legitimately omits dpi/orientation; it inherits from default.
      expect(described_class.new).to be_valid
    end
  end

  describe "edit-only enforcement" do
    it "ignores submitted keys that do not already exist in the structure" do
      model = build_model({ "default" => { "brand_new_key" => "x" } })

      expect(model.to_h["default"]).not_to have_key("brand_new_key")
    end
  end

  describe "fork passthrough" do
    let(:stored) do
      Settings::DEFAULTS[:pdf].deep_stringify_keys.tap do |h|
        h["default"]["gutter"] = "0.1875in"
      end
    end

    it "preserves unknown keys and does not validate them" do
      model = described_class.new(stored: stored, submitted: { "default" => { "dpi" => "80" } })

      expect(model).to be_valid
      expect(model.to_h.dig("default", "gutter")).to eq("0.1875in")
      expect(model.to_h.dig("default", "dpi")).to eq(80)
    end

    it "casts an edited unknown key by inference from its current type" do
      stored["default"]["custom_count"] = 3 # integer

      model = described_class.new(stored: stored, submitted: { "default" => { "custom_count" => "7" } })

      expect(model.to_h.dig("default", "custom_count")).to eq(7)
    end
  end
end
