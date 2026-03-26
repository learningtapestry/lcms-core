# frozen_string_literal: true

require "rails_helper"

describe PluginDemo::Tag do
  it "has valid factory" do
    expect(build(:plugin_demo_tag)).to be_valid
  end

  it "uses tags table" do
    expect(described_class.table_name).to eq("tags")
  end

  describe "validations" do
    it "requires a name" do
      tag = build(:plugin_demo_tag, name: nil)
      expect(tag).not_to be_valid
    end

    it "requires a unique name" do
      create(:plugin_demo_tag, name: "unique-tag")
      duplicate = build(:plugin_demo_tag, name: "unique-tag")
      expect(duplicate).not_to be_valid
    end
  end

  describe "associations" do
    it "has many taggings" do
      tag = create(:plugin_demo_tag)
      tagging = create(:plugin_demo_tagging, tag: tag)

      expect(tag.taggings).to include(tagging)
    end

    it "destroys taggings when destroyed" do
      tag = create(:plugin_demo_tag)
      create(:plugin_demo_tagging, tag: tag)

      expect { tag.destroy }.to change(PluginDemo::Tagging, :count).by(-1)
    end
  end
end
