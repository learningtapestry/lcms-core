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

    # Tables::Base#fetch_materials resolves [material: id] tokens from these
    # same cells on SPLIT_REGEX, so an author may separate entries with
    # semicolons or newlines.
    it "splits on semicolons and newlines too, so entries still dedupe" do
      mixed = Struct.new(:activity_materials_student, :activity_materials_pair,
                         :activity_materials_group, :activity_materials_class,
                         :activity_materials_teacher, keyword_init: true).new(
                           activity_materials_student: "Beakers; Tongs",
                           activity_materials_pair: "Tongs",
                           activity_materials_group: "Ring stand\nClamp",
                           activity_materials_class: nil,
                           activity_materials_teacher: nil
                         )

      expect(helper.activity_materials_list(mixed))
        .to eq("Beakers, Tongs, Ring stand, Clamp")
    end
  end

  describe "#resolve_material_tokens" do
    # Both activity templates emit this with `raw`, and the source cells are
    # decoded plain text — so markup characters must not reach the renderer.
    it "escapes authored text that contains markup characters" do
      expect(helper.resolve_material_tokens("Beaker <250 ml> & tongs"))
        .to eq("Beaker &lt;250 ml&gt; &amp; tongs")
    end

    it "still resolves material tokens in escaped text" do
      create(:material, identifier: "esc.01", metadata: { "material-title" => "Slides 01" })

      expect(helper.resolve_material_tokens("Use [material: esc.01]"))
        .to include(%(<span class="o-ld-material">Slides 01</span>))
    end
  end

  describe "#student_grouping_label" do
    context "when the key is configured in Settings" do
      before { Settings.set(:documents, "student_groupings" => { "class" => "Whole Class" }) }

      it "returns the configured label" do
        expect(helper.student_grouping_label("class")).to eq("Whole Class")
      end
    end

    context "when the key is not configured" do
      before { Settings.set(:documents, "student_groupings" => { "class" => "Whole Class" }) }

      it "falls back to titleizing the raw key" do
        expect(helper.student_grouping_label("small group")).to eq("Small Group")
      end
    end

    it "is blank for a blank value" do
      expect(helper.student_grouping_label("")).to eq("")
      expect(helper.student_grouping_label(nil)).to eq("")
    end
  end

  describe "#activity_type_label" do
    before { Settings.set(:documents, "activity_types" => { "WU" => "Warm-Up" }) }

    it "returns the configured label" do
      expect(helper.activity_type_label("WU")).to eq("Warm-Up")
    end

    it "looks up case-insensitively" do
      expect(helper.activity_type_label("wu")).to eq("Warm-Up")
    end

    it "falls back to titleizing the raw value when unconfigured" do
      expect(helper.activity_type_label("investigation")).to eq("Investigation")
    end

    it "is blank for a blank value" do
      expect(helper.activity_type_label("")).to eq("")
      expect(helper.activity_type_label(nil)).to eq("")
    end
  end
end
