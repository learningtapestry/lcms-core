# frozen_string_literal: true

require "rails_helper"

describe PluginDemo::TagService do
  subject(:service) { described_class.new }

  describe "#all_tags" do
    it "returns tags ordered by name" do
      tag_z = create(:tag, name: "z-tag")
      tag_a = create(:tag, name: "a-tag")

      result = service.all_tags

      expect(result.first).to eq(tag_a)
      expect(result.last).to eq(tag_z)
    end
  end

  describe "#demo_tag" do
    context "when demo tag exists" do
      it "returns the demo tag" do
        demo_tag = create(:tag, name: PluginDemo::TagService::DEMO_TAG_NAME)

        expect(service.demo_tag).to eq(demo_tag)
      end
    end

    context "when demo tag does not exist" do
      it "returns nil" do
        expect(service.demo_tag).to be_nil
      end
    end
  end

  describe "#ensure_demo_tag_exists!" do
    context "when demo tag does not exist" do
      it "creates the demo tag" do
        expect { service.ensure_demo_tag_exists! }.to change(Tag, :count).by(1)
      end

      it "returns the created tag" do
        tag = service.ensure_demo_tag_exists!

        expect(tag.name).to eq(PluginDemo::TagService::DEMO_TAG_NAME)
      end
    end

    context "when demo tag already exists" do
      before { create(:tag, name: PluginDemo::TagService::DEMO_TAG_NAME) }

      it "does not create a duplicate" do
        expect { service.ensure_demo_tag_exists! }.not_to change(Tag, :count)
      end

      it "returns the existing tag" do
        tag = service.ensure_demo_tag_exists!

        expect(tag.name).to eq(PluginDemo::TagService::DEMO_TAG_NAME)
      end
    end
  end

  describe "#demo_tag_exists?" do
    it "returns true when demo tag exists" do
      create(:tag, name: PluginDemo::TagService::DEMO_TAG_NAME)

      expect(service.demo_tag_exists?).to be true
    end

    it "returns false when demo tag does not exist" do
      expect(service.demo_tag_exists?).to be false
    end
  end
end
