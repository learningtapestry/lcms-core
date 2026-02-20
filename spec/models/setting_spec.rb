# frozen_string_literal: true

require "rails_helper"

RSpec.describe Setting, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:key) }
  end

  describe ".merge_with_defaults" do
    it "correctly selects the values or their defaults" do
      key = :appearance
      settings = { "header_bg_color" => "#ff0000", "header_text_color" => nil }

      result = described_class.merge_with_defaults(key, settings)

      defaults = SETTINGS_DEFAULTS[:appearance]

      expect(result[:header_bg_color]).to eq("#ff0000")
      expect(result[:header_text_color]).to eq(defaults[:header_text_color])
      expect(result[:header_dropdown_bg_color]).to eq(defaults[:header_dropdown_bg_color])
      expect(result[:header_active_item_color]).to eq(defaults[:header_active_item_color])
      expect(result[:header_logo]).to eq(defaults[:header_logo])
    end

    it "returns all defaults when given an empty hash" do
      result = described_class.merge_with_defaults(:appearance, {})

      SETTINGS_DEFAULTS[:appearance].each do |key, default_value|
        expect(result[key]).to eq(default_value)
      end
    end

    it "returns all defaults when given nil" do
      result = described_class.merge_with_defaults(:appearance, nil)

      SETTINGS_DEFAULTS[:appearance].each do |key, default_value|
        expect(result[key]).to eq(default_value)
      end
    end
  end

  describe ".get" do
    it "returns the raw setting value without defaults" do
      described_class.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })
      result = described_class.get(:appearance)

      expect(result).to eq({ "header_bg_color" => "#ff0000" })
    end

    it "returns the setting value merged with defaults" do
      described_class.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })
      result = described_class.get(:appearance, include_defaults: true)

      expect(result[:header_bg_color]).to eq("#ff0000")
      expect(result[:header_text_color]).to eq(SETTINGS_DEFAULTS[:appearance][:header_text_color])
    end

    it "returns all defaults when the setting is not present" do
      result = described_class.get(:appearance, include_defaults: true)

      SETTINGS_DEFAULTS[:appearance].each do |key, default_value|
        expect(result[key]).to eq(default_value)
      end
    end

    it "returns nil when the setting is not present and defaults are not included" do
      result = described_class.get(:nonexistent_key)
      expect(result).to be_nil
    end
  end

  describe ".get_multiple" do
    it "returns an empty hash when no settings exist" do
      result = described_class.get_multiple(%w(header_bg_color header_text_color))
      expect(result).to be_empty
    end

    it "returns stored values" do
      described_class.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })
      described_class.create!(key: :other, value: { "some_key" => "Hello World!" })

      result = described_class.get_multiple(%i(appearance other), include_defaults: false)

      expect(result[:appearance]["header_bg_color"]).to eq("#ff0000")
      expect(result[:other]["some_key"]).to eq("Hello World!")
    end

    it "returns stored values with defaults" do
      described_class.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })
      described_class.create!(key: :other, value: { "some_key" => "Hello World!" })

      result = described_class.get_multiple(%i(appearance other), include_defaults: true)

      expect(result[:appearance][:header_bg_color]).to eq("#ff0000")
      expect(result[:other][:some_key]).to eq("Hello World!")

      SETTINGS_DEFAULTS[:appearance].each do |key, default_value|
        next if key == :header_bg_color

        expect(result[:appearance][key]).to eq(default_value)
      end
    end
  end

  describe ".set" do
    it "creates a new setting when it does not exist" do
      expect {
        described_class.set(:appearance, { "header_bg_color" => "#ff0000" })
      }.to change(described_class, :count).by(1)

      expect(described_class.find_by(key: :appearance).value).to eq({ "header_bg_color" => "#ff0000" })
    end

    it "updates an existing setting" do
      described_class.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })

      expect {
        described_class.set(:appearance, { "header_bg_color" => "#00ff00" })
      }.not_to change(described_class, :count)

      expect(described_class.find_by(key: :appearance).value).to eq({ "header_bg_color" => "#00ff00" })
    end

    it "does nothing when value is nil" do
      expect {
        described_class.set(:appearance, nil)
      }.not_to change(described_class, :count)
    end

    it "does not overwrite existing setting when value is nil" do
      described_class.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })

      described_class.set(:appearance, nil)

      expect(described_class.find_by(key: :appearance).value).to eq({ "header_bg_color" => "#ff0000" })
    end

    it "saves an empty hash" do
      described_class.set(:appearance, {})

      expect(described_class.find_by(key: :appearance).value).to eq({})
    end
  end

  describe ".unset" do
    it "destroys an existing setting" do
      described_class.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })

      expect {
        described_class.unset(:appearance)
      }.to change(described_class, :count).by(-1)

      expect(described_class.find_by(key: :appearance)).to be_nil
    end

    it "does nothing when the setting does not exist" do
      expect {
        described_class.unset("nonexistent_key")
      }.not_to change(described_class, :count)
    end
  end

  describe ".unset_within" do
    it "unsets a specific sub key within a key" do
      described_class.create!(key: :appearance, value: { "header_bg_color" => "#ff0000", "header_text_color" => "#000000" })

      expect {
        described_class.unset_within(:appearance, :header_bg_color)
      }.not_to change(described_class, :count)

      expect(described_class.find_by(key: :appearance).value).to eq({ "header_text_color" => "#000000" })
    end
  end
end
