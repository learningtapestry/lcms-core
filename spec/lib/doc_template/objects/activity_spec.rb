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
             "activity-time" => "2 min", "activity-label" => "" },
           { "activity-type" => "Fluency Activity",
             "activity-title" => "Unit Form Counting from 398 to 405",
             "activity-time" => "", "activity-label" => "" },
           { "activity-type" => "Fluency Activity",
             "activity-title" => "Unit Form Counting from 398 to 405",
             "activity-time" => "3 min", "activity-label" => "" }]
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

      describe "with materials" do
        let(:material_ids) { [1, 2] }
        let(:activity_table) do
          [{ "section-title" => "Opening", "activity-type" => "Fluency Activity",
             "activity-title" => "Skip-Count by Tens",
             "material_ids" => material_ids,
             "activity-time" => "2 min", "activity-label" => "" }]
        end

        it "returns material ids" do
          expect(subject.children[0].material_ids).to eq material_ids
        end
      end
    end

    describe "defaults, fallbacks and coercion" do
      let(:activity_table) do
        [{ "activity-title" => "Warm Up",
           "activity-title-spanish" => "Calentamiento",
           "activity-time" => "5",
           "activity-label" => "optional",
           "lms-enabled" => "Yes",
           "lms-title" => "",
           "lms-title-spanish" => "",
           "submission-type" => "text",
           "submission-required" => "No",
           "grading-format" => "points",
           "grading-required" => "No" }]
      end

      it "applies defaults, infers booleans and coerces types" do
        activity = subject.children[0]

        expect(activity.lms_title).to eq "Warm Up"
        expect(activity.lms_title_spanish).to eq "Calentamiento"
        expect(activity.submission_required).to be true
        expect(activity.grading_required).to be true
        expect(activity.optional).to be true
        expect(activity.lms_enabled).to be true
        expect(activity.activity_time).to eq 5
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

  describe "optional flag (via activity-label)" do
    it "parses 'optional' label to true" do
      activity = described_class.build_from([{ "activity-label" => "optional" }])
      expect(activity.children[0].optional).to be true
    end

    it "parses nil label to falsey" do
      activity = described_class.build_from([{ "activity-label" => nil }])
      expect(activity.children[0].optional).to be_falsey
    end

    it "parses other label values to false" do
      activity = described_class.build_from([{ "activity-label" => "required" }])
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
