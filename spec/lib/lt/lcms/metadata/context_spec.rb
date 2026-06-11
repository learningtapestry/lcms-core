# frozen_string_literal: true

require "rails_helper"

describe Lt::Lcms::Metadata::Context do
  shared_examples "reordable" do |curriculum_type|
    subject { described_class.send("update_#{curriculum_type}s_level_position_for", children) }

    it "reorders #{curriculum_type}s" do
      subject
      expect(parent.reload.children.map(&:short_title)).to eq result
    end
  end

  context ".update_grades_level_position_for" do
    let(:parent) { build_or_return_resources_chain(["math"]) }
    let!(:children) do
      ["grade 11", "grade 9", "grade 10"].map do |grade|
        create(:resource, :grade, parent:, short_title: grade)
      end
    end
    let(:result) { ["grade 9", "grade 10", "grade 11"] }

    include_examples "reordable", "grade"
  end

  context ".update_units_level_position_for" do
    let(:parent) { build_or_return_resources_chain(["math", "grade 1"]) }
    let!(:children) do
      %w(u4 u3 u1 u2).map do |unit|
        create(:resource, :unit, parent:, short_title: unit)
      end
    end
    let(:result) { %w(u1 u2 u3 u4) }

    include_examples "reordable", "unit"
  end

  context ".update_sections_level_position_for" do
    let(:parent) { build_or_return_resources_chain(["math", "grade 1", "F1"]) }
    let!(:children) do
      ["section 10", "section 4", "section 5"].map do |section|
        create(:resource, curriculum_type: "section", parent:, short_title: section)
      end
    end
    let(:result) { ["section 4", "section 5", "section 10"] }

    include_examples "reordable", "section"
  end

  describe "lesson-metadata key accessors" do
    let(:metadata) do
      {
        "subject" => "math",
        "grade" => "10",
        "unit-id" => "GG",
        "section-number" => "",
        "lesson-number" => "7"
      }
    end
    let(:instance) { described_class.new(metadata) }

    it "reads unit from unit-id" do
      expect(instance.send(:unit)).to eq("gg")
    end

    it "reads lesson from lesson-number" do
      expect(instance.send(:lesson)).to eq(7)
    end

    it "returns blank section when section-number is empty" do
      expect(instance.send(:section)).to eq("")
    end

    it "builds directory from new keys" do
      expect(instance.directory).to eq(["math", "10", "gg", 7])
    end

    context "with numeric unit-id" do
      before { metadata["unit-id"] = "2" }

      it "coerces unit to integer" do
        expect(instance.send(:unit)).to eq(2)
      end
    end

    context "with unsupported subject" do
      before { metadata["subject"] = "history" }

      it "raises a descriptive error" do
        expect { instance.send(:subject) }.to raise_error(/Unsupported subject "history"/)
      end
    end

    context "with blank subject" do
      before { metadata["subject"] = "" }

      it "returns nil without raising" do
        expect(instance.send(:subject)).to be_nil
      end
    end
  end
end
