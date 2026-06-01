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
      before { Setting.set(:documents, "copyright_text" => "© Acme, Spring 2026") }

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

  describe "#footer_breadcrumb" do
    it "joins grade label, unit title, and lesson label with bullets" do
      result = presenter.footer_breadcrumb

      expect(result).to eq("Grade 3/Course • Unit 1 • Lesson 5")
    end

    context "when all parts are missing" do
      let(:document) { Document.new(metadata: { "subject" => "math" }) }

      it "returns nil" do
        expect(presenter.footer_breadcrumb).to be_nil
      end
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

      it "resolves [material: id] tokens to italic identifier links when the material exists" do
        create(:material, identifier: "worksheet01")

        summary = presenter.materials_summary

        expect(summary["Individual Student Materials"])
          .to include('<a class="o-ld-material">worksheet01</a>')
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
end
