# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Objects::Sections do
  describe ".build_from" do
    let(:data) do
      [
        { "section-title" => "Opening", "section-summary" => "<p>Some <b>HTML</b></p>" },
        { "section-title" => "Work Time", "section-summary" => "plain text" }
      ]
    end

    subject { described_class.build_from(data) }

    it "creates section children" do
      expect(subject.children.size).to eq 2
    end

    it "strips section- prefix from keys" do
      expect(subject.children[0].title).to eq "Opening"
      expect(subject.children[1].title).to eq "Work Time"
    end

    it "sanitizes HTML in summary" do
      expect(subject.children[0].summary).not_to include("<p>")
      expect(subject.children[0].summary).not_to include("<b>")
    end

    it "assigns sequential indexes" do
      expect(subject.children[0].idx).to eq 1
      expect(subject.children[1].idx).to eq 2
    end
  end

  describe "Section" do
    describe "#add_activity" do
      let(:section) do
        described_class.build_from([{ "section-title" => "Opening", "section-summary" => "" }]).children[0]
      end

      let(:activities) do
        DocTemplate::Objects::Activity.build_from([
          { "activity-title" => "A", "activity-time" => "2 min" },
          { "activity-title" => "B", "activity-time" => "3 min" }
        ])
      end

      it "accumulates time from activities" do
        activities.children.each { |a| section.add_activity(a) }
        expect(section.time).to eq 5
      end

      it "marks activities as handled" do
        activities.children.each { |a| section.add_activity(a) }
        expect(activities.children).to all(have_attributes(handled: true))
      end

      it "appends activities to children" do
        activities.children.each { |a| section.add_activity(a) }
        expect(section.children.size).to eq 2
      end
    end

    describe "#anchor" do
      let(:sections) do
        described_class.build_from([{ "section-title" => "Opening", "section-summary" => "" }])
      end

      it "computes anchor from idx, template_type, level, and title" do
        section = sections.children[0]
        expect(section.anchor).to eq "1-core-1-opening"
      end
    end

    describe "hash-style access" do
      let(:section) do
        described_class.build_from([{ "section-title" => "Opening", "section-summary" => "" }]).children[0]
      end

      it "raises for undeclared attributes" do
        expect { section[:use_color] }.to raise_error(NoMethodError)
      end

      it "reads declared attributes" do
        expect(section[:title]).to eq "Opening"
      end
    end

    describe "defaults" do
      let(:section) do
        described_class.build_from([{ "section-title" => "Test", "section-summary" => "" }]).children[0]
      end

      it "defaults template_type to core" do
        expect(section.template_type).to eq "core"
      end

      it "defaults handled to false" do
        expect(section.handled).to be false
      end

      it "defaults time to 0" do
        expect(section.time).to eq 0
      end

      it "defaults level to 1" do
        expect(section.level).to eq 1
      end

      it "defaults material_ids to empty array" do
        expect(section.material_ids).to eq []
      end
    end
  end

  describe "#add_break" do
    let(:sections) do
      described_class.build_from([
        { "section-title" => "Opening", "section-summary" => "" },
        { "section-title" => "Work Time", "section-summary" => "" }
      ])
    end

    before do
      sections.children[0].handled = true
    end

    it "inserts a break section before the first unhandled section" do
      sections.add_break
      titles = sections.children.map(&:title)
      expect(titles).to include("Foundational Skills Lesson")
    end

    it "sets anchor to optbreak" do
      sections.add_break
      break_section = sections.children.find { |c| c.title == "Foundational Skills Lesson" }
      expect(break_section.anchor).to eq "optbreak"
    end
  end

  describe "#level1_by_title" do
    let(:sections) do
      described_class.build_from([
        { "section-title" => "Opening", "section-summary" => "" },
        { "section-title" => "Opening", "section-summary" => "" }
      ])
    end

    it "returns the first unhandled section matching title" do
      first = sections.level1_by_title("opening")
      expect(first).to eq sections.children[0]
    end

    it "marks returned section as handled" do
      first = sections.level1_by_title("opening")
      expect(first.handled).to be true
    end

    it "returns the next unhandled section on second call" do
      first = sections.level1_by_title("opening")
      second = sections.level1_by_title("opening")
      expect(second).to eq sections.children[1]
      expect(first).not_to eq second
    end

    it "raises when no matching section found" do
      expect { sections.level1_by_title("nonexistent") }.to raise_error(DocumentError)
    end
  end
end
