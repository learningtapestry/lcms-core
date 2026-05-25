# frozen_string_literal: true

require "rails_helper"

RSpec.describe Settings do
  describe ".merge_with_defaults" do
    it "correctly selects the values or their defaults" do
      key = :appearance
      settings = { "header_bg_color" => "#ff0000", "header_text_color" => nil }

      result = described_class.merge_with_defaults(key, settings)

      defaults = described_class::DEFAULTS[:appearance]

      expect(result[:header_bg_color]).to eq("#ff0000")
      expect(result[:header_text_color]).to eq(defaults[:header_text_color])
      expect(result[:header_dropdown_bg_color]).to eq(defaults[:header_dropdown_bg_color])
      expect(result[:header_active_item_color]).to eq(defaults[:header_active_item_color])
      expect(result[:header_logo]).to eq(defaults[:header_logo])
    end

    it "returns all defaults when given an empty hash" do
      result = described_class.merge_with_defaults(:appearance, {})

      described_class::DEFAULTS[:appearance].each do |key, default_value|
        expect(result[key]).to eq(default_value)
      end
    end

    it "returns all defaults when given nil" do
      result = described_class.merge_with_defaults(:appearance, nil)

      described_class::DEFAULTS[:appearance].each do |key, default_value|
        expect(result[key]).to eq(default_value)
      end
    end
  end

  describe ".get" do
    it "returns the raw setting value without defaults" do
      Setting.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })
      result = described_class.get(:appearance)

      expect(result).to eq({ "header_bg_color" => "#ff0000" })
    end

    it "returns the setting value merged with defaults" do
      Setting.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })
      result = described_class.get(:appearance, include_defaults: true)

      expect(result[:header_bg_color]).to eq("#ff0000")
      expect(result[:header_text_color]).to eq(described_class::DEFAULTS[:appearance][:header_text_color])
    end

    it "returns all defaults when the setting is not present" do
      result = described_class.get(:appearance, include_defaults: true)

      described_class::DEFAULTS[:appearance].each do |key, default_value|
        expect(result[key]).to eq(default_value)
      end
    end

    it "returns nil when the setting is not present and defaults are not included" do
      result = described_class.get(:nonexistent_key)
      expect(result).to be_nil
    end
  end

  describe ".get_multiple" do
    it "returns nils when no settings exist (no defaults requested)" do
      result = described_class.get_multiple(%i(appearance other))
      expect(result).to eq(appearance: nil, other: nil)
    end

    it "returns stored values" do
      Setting.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })
      Setting.create!(key: :other, value: { "some_key" => "Hello World!" })

      result = described_class.get_multiple(%i(appearance other))

      expect(result[:appearance]["header_bg_color"]).to eq("#ff0000")
      expect(result[:other]["some_key"]).to eq("Hello World!")
    end

    it "returns stored values with defaults" do
      Setting.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })
      Setting.create!(key: :other, value: { "some_key" => "Hello World!" })

      result = described_class.get_multiple(%i(appearance other), include_defaults: true)

      expect(result[:appearance][:header_bg_color]).to eq("#ff0000")
      expect(result[:other][:some_key]).to eq("Hello World!")

      described_class::DEFAULTS[:appearance].each do |key, default_value|
        next if key == :header_bg_color

        expect(result[:appearance][key]).to eq(default_value)
      end
    end
  end

  describe ".set" do
    it "creates a new setting when it does not exist" do
      expect {
        described_class.set(:appearance, { "header_bg_color" => "#ff0000" })
      }.to change(Setting, :count).by(1)

      expect(Setting.find_by(key: :appearance).value).to eq({ "header_bg_color" => "#ff0000" })
    end

    it "updates an existing setting" do
      Setting.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })

      expect {
        described_class.set(:appearance, { "header_bg_color" => "#00ff00" })
      }.not_to change(Setting, :count)

      expect(Setting.find_by(key: :appearance).value).to eq({ "header_bg_color" => "#00ff00" })
    end

    it "does nothing when value is nil" do
      expect {
        described_class.set(:appearance, nil)
      }.not_to change(Setting, :count)
    end

    it "does not overwrite existing setting when value is nil" do
      Setting.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })

      described_class.set(:appearance, nil)

      expect(Setting.find_by(key: :appearance).value).to eq({ "header_bg_color" => "#ff0000" })
    end

    it "saves an empty hash" do
      described_class.set(:appearance, {})

      expect(Setting.find_by(key: :appearance).value).to eq({})
    end
  end

  describe ".unset" do
    it "destroys an existing setting" do
      Setting.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })

      expect {
        described_class.unset(:appearance)
      }.to change(Setting, :count).by(-1)

      expect(Setting.find_by(key: :appearance)).to be_nil
    end

    it "does nothing when the setting does not exist" do
      expect {
        described_class.unset("nonexistent_key")
      }.not_to change(Setting, :count)
    end
  end

  describe ".unset_within" do
    it "unsets a specific sub key within a key" do
      Setting.create!(
        key: :appearance,
        value: { "header_bg_color" => "#ff0000", "header_text_color" => "#000000" }
      )

      expect {
        described_class.unset_within(:appearance, :header_bg_color)
      }.not_to change(Setting, :count)

      expect(Setting.find_by(key: :appearance).value).to eq({ "header_text_color" => "#000000" })
    end
  end

  describe "caching" do
    around do |example|
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
    ensure
      Rails.cache = original_cache
    end

    it "caches reads so the second call does not hit the database" do
      Setting.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })

      described_class.get(:appearance)

      expect(Setting).not_to receive(:find_by)
      result = described_class.get(:appearance)
      expect(result).to eq({ "header_bg_color" => "#ff0000" })
    end

    it "invalidates the cache after .set" do
      Setting.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })

      expect(described_class.get(:appearance)).to eq({ "header_bg_color" => "#ff0000" })

      described_class.set(:appearance, { "header_bg_color" => "#00ff00" })

      expect(described_class.get(:appearance)).to eq({ "header_bg_color" => "#00ff00" })
    end

    it "invalidates the cache after .unset" do
      Setting.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })

      expect(described_class.get(:appearance)).to eq({ "header_bg_color" => "#ff0000" })

      described_class.unset(:appearance)

      expect(described_class.get(:appearance)).to be_nil
    end

    it "uses distinct cache keys for include_defaults: true and false" do
      Setting.create!(key: :appearance, value: { "header_bg_color" => "#ff0000" })

      raw = described_class.get(:appearance)
      with_defaults = described_class.get(:appearance, include_defaults: true)

      expect(raw).to eq({ "header_bg_color" => "#ff0000" })
      expect(with_defaults[:header_bg_color]).to eq("#ff0000")
      expect(with_defaults[:header_text_color]).to eq(described_class::DEFAULTS[:appearance][:header_text_color])
    end
  end
end
