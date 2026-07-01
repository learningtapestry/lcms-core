# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tags::Helpers do
  let(:helper) { Class.new { include DocTemplate::Tags::Helpers }.new }

  describe "#number_to_word" do
    it "returns the cardinal word for a 1-based number" do
      expect(helper.number_to_word(1)).to eq("One")
      expect(helper.number_to_word(3)).to eq("Three")
    end

    it "falls back to the numeral beyond the lookup table" do
      expect(helper.number_to_word(42)).to eq("42")
    end

    it "is blank for nil" do
      expect(helper.number_to_word(nil)).to eq("")
    end
  end

  describe "#activity_materials_list" do
    let(:activity) do
      Struct.new(:activity_materials_student, :activity_materials_pair,
                 :activity_materials_group, :activity_materials_class,
                 :activity_materials_teacher, keyword_init: true).new(
                   activity_materials_student: "Notebook, Ruler",
                   activity_materials_pair: "Ruler",
                   activity_materials_group: nil,
                   activity_materials_class: "Lesson 7 Slides",
                   activity_materials_teacher: "Answer Key"
                 )
    end

    it "compiles, dedupes, and comma-joins across all grouping fields" do
      expect(helper.activity_materials_list(activity))
        .to eq("Notebook, Ruler, Lesson 7 Slides, Answer Key")
    end

    it "is blank when no grouping field has materials" do
      blank = Struct.new(:activity_materials_student, :activity_materials_pair,
                         :activity_materials_group, :activity_materials_class,
                         :activity_materials_teacher, keyword_init: true).new
      expect(helper.activity_materials_list(blank)).to eq("")
    end
  end
end
