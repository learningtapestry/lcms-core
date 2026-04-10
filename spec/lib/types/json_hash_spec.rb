# frozen_string_literal: true

require "rails_helper"

describe Types::JsonHash do
  subject(:type) { described_class.new }

  describe "#cast" do
    it "passes hashes through" do
      expect(type.cast({ a: 1 })).to eq({ a: 1 })
    end

    it "casts nil to empty hash" do
      expect(type.cast(nil)).to eq({})
    end

    it "preserves empty hashes" do
      expect(type.cast({})).to eq({})
    end

    it "converts objects that respond to to_h" do
      obj = double(to_h: { key: "value" })
      expect(type.cast(obj)).to eq({ key: "value" })
    end

    it "returns empty hash for objects that do not respond to to_h" do
      expect(type.cast("not a hash")).to eq({})
    end
  end

  describe "#type" do
    it "returns :json_hash" do
      expect(type.type).to eq :json_hash
    end
  end
end
