# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Objects::Activity do
  describe ".build_from" do
    subject { DocTemplate::Objects::Activity.build_from(activity_table) }
    let(:sections) { DocTemplate::Objects::Sections.build_from(sections_table) }

    describe "empty data" do
      let(:activity_table) { [] }

      it "returns empty object" do
        expect(subject.children.size).to eq 0
      end
    end

    describe "correct data" do
      describe "with single section" do
        let(:activity_table) do
          [{ "activity-type" => "Fluency Activity",
             "activity-title" => "Skip-Count by Tens: Up and Down Crossing 100",
             "activity-source" => "ENY-G2-M3-L1-F#4", "activity-materials" => "",
             "activity-standard" => "2.NBT.A.2", "activity-mathematical-practice" => "",
             "activity-time" => "2 min", "activity-priority" => "2", "activity-metacognition" => "",
             "activity-guidance" => "", "activity-content-development-notes" => "" },
           { "activity-type" => "Fluency Activity",
             "activity-title" => "Unit Form Counting from 398 to 405", "activity-source" => "ENY-G2-M3-L6-F#2",
             "activity-materials" => "ENY-G2-M3-L4-T#1", "activity-standard" => "2.NBT.A.3",
             "activity-mathematical-practice" => "6", "activity-time" => "", "activity-priority" => "1",
             "activity-metacognition" => "", "activity-guidance" => "", "activity-content-development-notes" => "" },
           { "activity-type" => "Fluency Activity",
             "activity-title" => "Unit Form Counting from 398 to 405", "activity-source" => "ENY-G2-M3-L6-F#2",
             "activity-materials" => "ENY-G2-M3-L4-T#1", "activity-standard" => "2.NBT.A.3",
             "activity-mathematical-practice" => "6", "activity-time" => "3 min", "activity-priority" => "1",
             "activity-metacognition" => "", "activity-guidance" => "", "activity-content-development-notes" => "" }]
        end

        let(:sections_table) do
          [{ "section-title" => "Opening", "section-summary" => "bla bla bla" }]
        end

        before do
          subject.children.each { |a| sections.children[0].add_activity a }
        end

        it "returns valid object" do
          expect(subject.children.size).to eq 3
          expect(subject.children[0].title).to eq "Skip-Count by Tens: Up and Down Crossing 100"
          expect(subject.children[0].time).to eq 2
          expect(subject.children[1].activity_time).to eq 0
          expect(subject.children[2].time).to eq 3

          expect(sections.children[0].children.size).to eq 3
          expect(sections.children[0].time).to eq 5
          expect(sections.children[0].title).to eq "Opening"
        end
      end

      describe "with multiple section" do
        let(:activity_table) do
          [{ "activity-type" => "Fluency Activity",
             "activity-title" => "Skip-Count by Tens: Up and Down Crossing 100",
             "activity-source" => "ENY-G2-M3-L1-F#4", "activity-materials" => "",
             "activity-standard" => "2.NBT.A.2", "activity-mathematical-practice" => "",
             "activity-time" => "2 min", "activity-priority" => "2", "activity-metacognition" => "",
             "activity-guidance" => "", "activity-content-development-notes" => "" },
           { "activity-type" => "Fluency Activity",
             "activity-title" => "Unit Form Counting from 398 to 405", "activity-source" => "ENY-G2-M3-L6-F#2",
             "activity-materials" => "ENY-G2-M3-L4-T#1", "activity-standard" => "2.NBT.A.3",
             "activity-mathematical-practice" => "6", "activity-time" => "", "activity-priority" => "1",
             "activity-metacognition" => "", "activity-guidance" => "", "activity-content-development-notes" => "" },
           { "activity-type" => "Fluency Activity",
             "activity-title" => "Unit Form Counting from 398 to 405", "activity-source" => "ENY-G2-M3-L6-F#2",
             "activity-materials" => "ENY-G2-M3-L4-T#1", "activity-standard" => "2.NBT.A.3",
             "activity-mathematical-practice" => "6", "activity-time" => "3 min", "activity-priority" => "1",
             "activity-metacognition" => "", "activity-guidance" => "", "activity-content-development-notes" => "" }]
        end

        let(:sections_table) do
          [{ "section-title" => "Opening", "section-summary" => "bla bla bla" },
           { "section-title" => "Opening 2", "section-summary" => "ble ble ble" }]
        end

        before do
          subject.children[0..1].each { |a| sections.children[0].add_activity a }
          sections.children.last.add_activity subject.children.last
        end

        it "returns valid object" do
          expect(sections.children.size).to eq 2
          expect(sections.children.first.title).to eq "Opening"
          expect(sections.children.last.title).to eq "Opening 2"
          expect(sections.children.first.time).to eq 2
          expect(sections.children.last.time).to eq 3
          expect(sections.children.first.children.size).to eq 2
          expect(sections.children.last.children.size).to eq 1
        end
      end

      describe "with materials" do
        let(:material_ids) { [1, 2] }
        let(:activity_table) do
          [{ "section-title" => "Opening", "activity-type" => "Fluency Activity",
             "activity-title" => "Skip-Count by Tens: Up and Down Crossing 100",
             "activity-source" => "ENY-G2-M3-L1-F#4", "material_ids" => material_ids,
             "activity-materials" => "", "activity-standard" => "2.NBT.A.2",
             "activity-mathematical-practice" => "", "activity-time" => "2 min",
             "activity-priority" => "2", "activity-metacognition" => "",
             "activity-guidance" => "", "activity-content-development-notes" => "" }]
        end

        it "returns material ids" do
          expect(subject.children[0].material_ids).to eq material_ids
        end
      end
    end
  end

  describe "time parsing" do
    it "parses '2 min' to 2" do
      activity = described_class.build_from([{ "activity-time" => "2 min" }])
      expect(activity.children[0].activity_time).to eq 2
    end

    it "parses empty string to 0" do
      activity = described_class.build_from([{ "activity-time" => "" }])
      expect(activity.children[0].activity_time).to eq 0
    end

    it "parses '15 min' to 15" do
      activity = described_class.build_from([{ "activity-time" => "15 min" }])
      expect(activity.children[0].activity_time).to eq 15
    end
  end

  describe "optional flag" do
    it "parses 'optional' to true" do
      activity = described_class.build_from([{ "optional" => "optional" }])
      expect(activity.children[0].optional).to be true
    end

    it "parses nil to nil" do
      activity = described_class.build_from([{ "optional" => nil }])
      expect(activity.children[0].optional).to be_nil
    end

    it "parses other values to false" do
      activity = described_class.build_from([{ "optional" => "no" }])
      expect(activity.children[0].optional).to be false
    end
  end

  describe "alias methods" do
    let(:activity) do
      described_class.build_from([{
        "activity-title" => "Test Activity",
        "activity-time" => "5 min",
        "activity-priority" => "2",
        "activity-standard" => "2.NBT.A.2"
      }])
    end

    let(:item) { activity.children[0] }

    it "title delegates to activity_title" do
      expect(item.title).to eq item.activity_title
    end

    it "time delegates to activity_time" do
      expect(item.time).to eq item.activity_time
    end

    it "priority delegates to activity_priority" do
      expect(item.priority).to eq item.activity_priority
    end
  end

  describe "defaults and mutability" do
    let(:activity) { described_class.build_from([{ "activity-title" => "Test" }]) }
    let(:item) { activity.children[0] }

    it "defaults handled to false" do
      expect(item.handled).to be false
    end

    it "allows handled to be set" do
      item.handled = true
      expect(item.handled).to be true
    end

    it "defaults material_ids to empty array" do
      expect(item.material_ids).to eq []
    end
  end

  describe "hash-style access" do
    let(:activity) do
      described_class.build_from([{
        "activity-title" => "Test",
        "activity-guidance" => "some guidance"
      }])
    end

    let(:item) { activity.children[0] }

    it "reads attributes via []" do
      expect(item[:activity_guidance]).to eq "some guidance"
    end

    it "writes attributes via []=" do
      item[:activity_guidance] = "new guidance"
      expect(item.activity_guidance).to eq "new guidance"
    end
  end

  describe "index assignment" do
    let(:activity) do
      described_class.build_from([
        { "activity-title" => "A" },
        { "activity-title" => "B" },
        { "activity-title" => "C" }
      ])
    end

    it "assigns sequential indexes" do
      expect(activity.children[0].idx).to eq 1
      expect(activity.children[1].idx).to eq 2
      expect(activity.children[2].idx).to eq 3
    end
  end
end
