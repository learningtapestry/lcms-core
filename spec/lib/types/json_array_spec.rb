# frozen_string_literal: true

require "rails_helper"

describe Types::JsonArray do
  subject(:type) { described_class.new }

  describe "#cast" do
    it "passes arrays through" do
      expect(type.cast([1, 2, 3])).to eq [1, 2, 3]
    end

    it "casts nil to empty array" do
      expect(type.cast(nil)).to eq []
    end

    it "wraps a single value in an array" do
      expect(type.cast("hello")).to eq ["hello"]
    end

    it "preserves empty arrays" do
      expect(type.cast([])).to eq []
    end

    it "preserves arrays of hashes" do
      data = [{ "op" => "create" }, { "op" => "remove" }]
      expect(type.cast(data)).to eq data
    end
  end

  describe "#type" do
    it "returns :json_array" do
      expect(type.type).to eq :json_array
    end
  end
end
