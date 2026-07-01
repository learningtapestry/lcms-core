# frozen_string_literal: true

require "rails_helper"

describe DocumentPresenter do
  let(:document) do
    create(:document, metadata: {
      "lesson_title" => "Introduction to Fractions",
      "grade" => "3",
      "unit_id" => "1",
      "section_number" => "1",
      "lesson_number" => "5",
      "subject" => "math"
    })
  end
  let(:presenter) { described_class.new(document) }

  describe "#gdoc_header" do
    context "when lesson_title is present" do
      it "returns 2D array with title placeholder and value" do
        result = presenter.gdoc_header

        expect(result).to eq([
          ["{title}"],
          ["Introduction to Fractions"]
        ])
      end
    end

    context "when lesson_title is blank" do
      let(:document) do
        create(:document, metadata: {
          "lesson_title" => "",
          "grade" => "3",
          "unit_id" => "1",
          "section_number" => "1",
          "lesson_number" => "5",
          "subject" => "math"
        })
      end

      it "returns empty string for title" do
        result = presenter.gdoc_header

        expect(result).to eq([
          ["{title}"],
          [""]
        ])
      end
    end
  end

  describe "integration with Google::ScriptService" do
    it "provides compatible format for ScriptService#parameters" do
      header = presenter.gdoc_header

      expect(header).to be_an(Array)
      expect(header.size).to eq(2)
      expect(header.all? { |row| row.is_a?(Array) }).to be true
    end
  end

  describe "#gdoc_footer" do
    context "with copyright_text Setting" do
      before { Settings.set(:documents, "copyright_text" => "© Acme, Spring 2026") }

      it "merges copyright_text into the attribution placeholder" do
        result = presenter.gdoc_footer

        expect(result).to eq([
          ["{attribution}"],
          ["© Acme, Spring 2026"]
        ])
      end
    end

    context "without any copyright info" do
      it "falls back to the placeholder default" do
        result = presenter.gdoc_footer

        expect(result).to eq([
          ["{attribution}"],
          ["Copyright attribution here"]
        ])
      end
    end
  end

  describe "#footer_unit_lesson" do
    it "joins unit title and lesson label with a bullet" do
      expect(presenter.footer_unit_lesson).to eq("Unit 1 • Lesson 5")
    end

    context "when unit and lesson are missing" do
      let(:document) { Document.new(metadata: { "subject" => "math" }) }

      it "returns nil" do
        expect(presenter.footer_unit_lesson).to be_nil
      end
    end
  end

  describe "footer lines from unit-metadata" do
    before { create(:curriculum) }

    let(:document) do
      create(:document, metadata: {
        "subject" => "math",
        "grade" => "6",
        "unit-id" => "2",
        "section-number" => "1",
        "lesson-number" => "3",
        "lesson-title" => "L3"
      })
    end

    before do
      # The unit Resource carries unit-metadata (populated by UnitBuildService).
      unit = document.resource.ancestors.find(&:unit?)
      unit.update_columns(metadata: unit.metadata.merge(
        "course" => "Biology", "version" => "v1.0", "unit-title" => "Cells"
      ))
    end

    it "#footer_course reads the course from unit-metadata" do
      expect(described_class.new(document).footer_course).to eq("Biology")
    end

    it "#footer_unit_lesson uses the unit-title from unit-metadata" do
      expect(described_class.new(document).footer_unit_lesson).to eq("Cells • Lesson 3")
    end

    it "#footer_copyright appends the unit version to the boilerplate copyright" do
      Settings.set(:documents, "copyright_text" => "© Acme")

      expect(described_class.new(document).footer_copyright).to eq("© Acme, v1.0")
    end
  end

  describe "#materials_summary" do
    context "when document has no activity metadata" do
      it "returns an empty hash" do
        expect(presenter.materials_summary).to eq({})
      end
    end

    context "when document has activity metadata" do
      let(:document) do
        create(:document,
               metadata: {
                 "lesson_title" => "Sample",
                 "grade" => "6",
                 "subject" => "science"
               },
               activity_metadata: [
                 { "activity-materials-student" => "Notebook, [material: worksheet01]",
                   "activity-materials-class" => "Lesson 7 Slides" },
                 { "activity-materials-student" => "[material: worksheet02]",
                   "activity-materials-pair" => "Calculator" }
               ])
      end

      it "aggregates and dedupes materials across activities" do
        summary = presenter.materials_summary

        expect(summary["Individual Student Materials"])
          .to eq("Notebook, worksheet01, worksheet02")
        expect(summary["Pair Materials"]).to eq("Calculator")
        expect(summary["Class Materials"]).to eq("Lesson 7 Slides")
      end

      it "resolves [material: id] tokens to identifier links matching MaterialTag when the material exists" do
        material = create(:material, identifier: "worksheet01")

        summary = presenter.materials_summary

        expect(summary["Individual Student Materials"])
          .to include(%(<a href="/materials/#{material.id}" class="o-ld-material" target="_blank" rel="noopener">worksheet01</a>))
        expect(summary["Individual Student Materials"])
          .not_to include("[material:")
      end

      it "strips brackets for unknown material tokens" do
        summary = presenter.materials_summary

        expect(summary["Individual Student Materials"]).to include("worksheet01")
        expect(summary["Individual Student Materials"]).not_to include("[material:")
      end

      it "renders empty rows as 'None'" do
        summary = presenter.materials_summary

        expect(summary["Small Group Materials"]).to eq("None")
        expect(summary["Teacher Materials"]).to eq("None")
      end

      it "always includes all five canonical rows" do
        expect(presenter.materials_summary.keys).to eq([
          "Individual Student Materials",
          "Pair Materials",
          "Small Group Materials",
          "Class Materials",
          "Teacher Materials"
        ])
      end
    end
  end

  describe "#vocabulary" do
    context "when activities define vocabulary" do
      let(:document) do
        create(:document,
               metadata: { "subject" => "math", "grade" => "6" },
               activity_metadata: [
                 { "vocabulary" => "energy, force" },
                 { "vocabulary" => "force, motion" },
                 { "vocabulary" => "" }
               ])
      end

      it "compiles and dedupes vocabulary across activities" do
        expect(presenter.vocabulary).to eq("energy, force, motion")
      end
    end

    context "when no activity defines vocabulary" do
      it "returns a blank string" do
        expect(presenter.vocabulary).to eq("")
      end
    end
  end

  describe "#estimated_time" do
    def with_activity_times(*times)
      create(:document,
             metadata: { "subject" => "math", "grade" => "6" },
             activity_metadata: times.map { |t| { "activity-time" => t.to_s } })
    end

    it "rounds total activity time up to whole 45-minute class periods" do
      # 45 → 1 period
      expect(described_class.new(with_activity_times(20, 25)).estimated_time)
        .to eq("1 Class Period")
      # 60 → 2 periods
      expect(described_class.new(with_activity_times(30, 30)).estimated_time)
        .to eq("2 Class Periods")
      # 135 → 3 periods
      expect(described_class.new(with_activity_times(45, 45, 45)).estimated_time)
        .to eq("3 Class Periods")
    end

    it "falls back to the authored estimated-time when no activity has a time" do
      document = create(:document, metadata: {
        "subject" => "math", "grade" => "6", "estimated-time" => "Two weeks"
      })

      expect(described_class.new(document).estimated_time).to eq("Two weeks")
    end

    it "is blank when there is neither activity time nor an authored value" do
      document = create(:document, metadata: { "subject" => "math", "grade" => "6" })

      expect(described_class.new(document).estimated_time).to be_blank
    end
  end

  describe "#lesson_prep_directions" do
    context "when the lesson defines preparation directions" do
      let(:document) do
        create(:document, metadata: {
          "subject" => "math",
          "grade" => "6",
          "lesson_prep" => { "lesson-prep-directions" => "<ol><li>Review slides</li></ol>" }
        })
      end

      it "returns the directions HTML" do
        expect(presenter.lesson_prep_directions).to eq("<ol><li>Review slides</li></ol>")
      end
    end

    context "when the lesson has no preparation directions" do
      it "is blank" do
        expect(presenter.lesson_prep_directions).to be_blank
      end
    end
  end

  describe "overview neighbour descriptions" do
    # A real curriculum tree is built from each document's metadata, so the
    # presenter can walk to the previous/next lesson within the same unit.
    before { create(:curriculum) }

    def create_lesson(num, attrs = {})
      create(:document, metadata: {
        "subject" => "math",
        "grade" => "3",
        "unit-id" => "1",
        "section-number" => "1",
        "lesson-number" => num.to_s,
        "lesson-title" => "Lesson #{num}"
      }.merge(attrs))
    end

    # Per the spec: `description-future` is blank for Lesson 1 and
    # `description-past` is blank for the last lesson of the unit.
    let!(:lesson1) do
      create_lesson(1, "description" => "this 1", "description-past" => "past 1", "description-future" => "")
    end
    let!(:lesson2) do
      create_lesson(2, "description" => "this 2", "description-past" => "past 2", "description-future" => "future 2")
    end
    let!(:lesson3) do
      create_lesson(3, "description" => "this 3", "description-past" => "", "description-future" => "future 3")
    end

    it "reads overview_past from the previous lesson's description-past" do
      expect(described_class.new(lesson2).overview_past).to eq("past 1")
    end

    it "reads overview_future from the next lesson's description-future" do
      expect(described_class.new(lesson2).overview_future).to eq("future 3")
    end

    it "returns nil overview_past for the first lesson of the unit" do
      expect(described_class.new(lesson1).overview_past).to be_nil
    end

    it "returns nil overview_future for the last lesson of the unit" do
      expect(described_class.new(lesson3).overview_future).to be_nil
    end
  end
end
