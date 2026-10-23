# frozen_string_literal: true

require "rails_helper"

# Tag configuration after config/tags.yml was retired: parser rules are
# constants on the tag classes (overridable by plugins through
# DocTemplate::Tags.config), wording and styling come from Settings[:documents].
describe "DocTemplate tag configuration" do
  describe "stop tags" do
    around do |example|
      original = DocTemplate::Tags.config
      example.run
    ensure
      DocTemplate::Tags.config = original
    end

    it "uses the tag class constants by default" do
      expect(DocTemplate::Tags::SectionTag.new.send(:stop_tags_for, :content)).to eq(%w(SectionTag))
      expect(DocTemplate::Tags::ActivityMetadataSectionTag.new.send(:stop_tags_for, :materials))
        .to eq(%w(ActivityMetadataSectionTag ActivityMetadataTypeTag))
    end

    it "has none for tags that do not define them" do
      expect(DocTemplate::Tags::LatexTag.new.send(:stop_tags_for, :content)).to eq([])
    end

    it "lets a plugin override them per tag" do
      DocTemplate::Tags.config = { "section" => { "stop_tags" => %w(MaterialsTag) } }

      expect(DocTemplate::Tags::SectionTag.new.send(:stop_tags_for, :content)).to eq(%w(MaterialsTag))
    end

    it "only names tag classes that exist" do
      tags = [
        DocTemplate::Tags::ActivityMetadataSectionTag, DocTemplate::Tags::ActivityMetadataTypeTag,
        DocTemplate::Tags::MaterialsTag, DocTemplate::Tags::SectionTag
      ]
      names = tags.flat_map { |tag| tag::STOP_TAGS + tag::STOP_MATERIALS_TAGS }.uniq

      names.each { |name| expect(DocTemplate::Tags.const_get(name)).to be < DocTemplate::Tags::BaseTag }
    end
  end

  describe "priority descriptions" do
    let(:activity) { Struct.new(:activity_priority).new(2) }

    it "come from the Settings defaults" do
      expect(DocTemplate::Tags::SectionTag.new.send(:priority_description, activity))
        .to start_with("This is a Priority 2 activity that can be moved or adapted")
      expect(DocTemplate::Tags::ActivityMetadataTypeTag.new.send(:priority_description, activity))
        .to start_with("This is a Priority 2 activity that can be skipped")
    end

    it "use an override stored in Settings" do
      Settings.set(:documents, "priority_descriptions" => { "section" => ["Must do", "Optional"] })

      expect(DocTemplate::Tags::SectionTag.new.send(:priority_description, activity)).to eq("Optional")
      expect(DocTemplate::Tags::ActivityMetadataTypeTag.new.send(:priority_description, activity))
        .to start_with("This is a Priority 2 activity that can be skipped")
    end

    it "are blank for a priority without a description" do
      expect(DocTemplate::Tags::SectionTag.new.send(:priority_description, Struct.new(:activity_priority).new(3)))
        .to be_nil
    end
  end

  describe "LaTeX color" do
    let(:tag) { DocTemplate::Tags::LatexTag.new.tap { _1.instance_variable_set(:@parent_node, Object.new) } }

    it "comes from the Settings default" do
      expect(tag.send(:custom_color)).to eq("0,166,153")
    end

    it "uses an override stored in Settings" do
      Settings.set(:documents, "latex_color" => "255,0,0")

      expect(tag.send(:custom_color)).to eq("255,0,0")
    end
  end
end
