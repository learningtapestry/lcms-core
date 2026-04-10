# frozen_string_literal: true

require "rails_helper"

describe PluginDemo::Tagging do
  it "has valid factory" do
    expect(create(:plugin_demo_tagging)).to be_valid
  end

  it "uses taggings table" do
    expect(described_class.table_name).to eq("taggings")
  end

  describe "associations" do
    it "belongs to a PluginDemo::Tag" do
      tagging = create(:plugin_demo_tagging)

      expect(tagging.tag).to be_a(PluginDemo::Tag)
    end

    it "belongs to a polymorphic taggable" do
      tagging = create(:plugin_demo_tagging)

      expect(tagging.taggable).to be_a(Resource)
    end
  end

  describe "validations" do
    it "requires a tag" do
      tagging = build(:plugin_demo_tagging, tag: nil)
      expect(tagging).not_to be_valid
    end

    it "requires a context" do
      tagging = build(:plugin_demo_tagging, context: nil)
      expect(tagging).not_to be_valid
    end
  end
end
