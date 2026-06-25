# frozen_string_literal: true

require "rails_helper"

RSpec.describe Setting::AdminViewLinks do
  def build_model(submitted, stored: Settings::DEFAULTS[:admin_view_links].deep_stringify_keys)
    described_class.new(stored: stored, submitted: submitted)
  end

  describe "the shipped defaults" do
    it "are valid against the schema" do
      expect(described_class.new).to be_valid
    end
  end

  describe "list casting" do
    it "splits a textarea value (one per line) into an array" do
      model = build_model({ "documents" => "/a/:id\n/b/:id\n" })

      expect(model.to_h["documents"]).to eq(["/a/:id", "/b/:id"])
    end

    it "treats an empty value as an empty list" do
      model = build_model({ "documents" => "" })

      expect(model.to_h["documents"]).to eq([])
    end
  end

  describe "edit-only enforcement" do
    it "ignores submitted keys that do not already exist" do
      model = build_model({ "brand_new" => "/x" })

      expect(model.to_h).not_to have_key("brand_new")
    end
  end
end
