# frozen_string_literal: true

require "rails_helper"

describe SectionPresenter do
  let(:metadata) { { "section_number" => "1", "section_title" => "Consumer Goods" } }
  let(:presenter) { described_class.new(Resource.new(title: "1", metadata:)) }

  def lesson(number, learning_targets = "")
    double("DocumentPresenter", lesson_number: number, learning_targets:)
  end

  describe "#overview_html" do
    it "is the authored description HTML" do
      metadata["description"] = "<p>Students <em>investigate</em>...</p>"

      expect(presenter.overview_html).to eq "<p>Students <em>investigate</em>...</p>"
    end

    it "is nil when blank" do
      expect(presenter.overview_html).to be_nil
    end
  end

  describe "#lesson_range" do
    it "spans the first and last lesson numbers" do
      allow(presenter).to receive(:lessons).and_return([lesson(3), lesson(4), lesson(5)])

      expect(presenter.lesson_range).to eq "3-5"
    end

    it "is a single number for a one-lesson section" do
      allow(presenter).to receive(:lessons).and_return([lesson(7)])

      expect(presenter.lesson_range).to eq "7"
    end

    it "is nil without numbered lessons" do
      allow(presenter).to receive(:lessons).and_return([lesson(nil)])

      expect(presenter.lesson_range).to be_nil
    end
  end

  describe "#lessons_label" do
    it "pluralizes a range and keeps a single lesson singular" do
      allow(presenter).to receive(:lesson_range).and_return("1-2")
      expect(presenter.lessons_label).to eq "Lessons 1-2"

      allow(presenter).to receive(:lesson_range).and_return("3")
      expect(presenter.lessons_label).to eq "Lesson 3"
    end

    it "is nil without a range" do
      allow(presenter).to receive(:lesson_range).and_return(nil)

      expect(presenter.lessons_label).to be_nil
    end
  end

  describe "#learning_targets" do
    it "gives one item per list item or paragraph across lessons, in lesson order" do
      allow(presenter).to receive(:lessons).and_return([
        lesson(1, "<ul><li>gather <strong>information</strong></li><li> </li><li>develop models</li></ul>"),
        lesson(2, "<p>use simulations</p><p></p><p>calculate emissions</p>"),
        lesson(3, "")
      ])

      expect(presenter.learning_targets).to eq [
        "gather <strong>information</strong>", "develop models", "use simulations", "calculate emissions"
      ]
    end

    it "keeps a nested list inside its parent item instead of repeating its items" do
      allow(presenter).to receive(:lessons).and_return([
        lesson(1, "<ol><li>develop models of<ol><li>extraction</li><li>waste</li></ol></li><li>use models</li></ol>")
      ])

      expect(presenter.learning_targets).to eq [
        "develop models of<ol>\n<li>extraction</li>\n<li>waste</li>\n</ol>", "use models"
      ]
    end

    it "escapes a plain-text value imported before the row kept its HTML" do
      allow(presenter).to receive(:lessons).and_return([lesson(1, "compare A & B")])

      expect(presenter.learning_targets).to eq ["compare A &amp; B"]
    end
  end

  describe "#section_materials" do
    let!(:roster) { create(:material, identifier: "roster-1") }

    it "resolves the section-materials row to material presenters" do
      metadata["section_materials"] = "Roster-1, missing-1"

      expect(presenter.section_materials.map(&:id)).to eq [roster.id]
      expect(presenter.section_materials).to all(be_a(MaterialPresenter))
    end
  end

  describe "#lessons" do
    def create_lesson(section, number, targets)
      create(:document, active: true, metadata: {
        "subject" => "math", "grade" => "3", "unit-id" => "u1",
        "section-number" => section.to_s, "lesson-number" => number.to_s, "learning_targets" => targets
      })
    end

    it "returns only this section's lessons, in order" do
      create_lesson(1, 2, "B")
      create_lesson(2, 1, "C")
      create_lesson(1, 1, "A")
      section = Resource.sections.where_metadata("section", "1").sole

      expect(described_class.new(section).lessons.map(&:learning_targets)).to eq %w(A B)
    end
  end
end
