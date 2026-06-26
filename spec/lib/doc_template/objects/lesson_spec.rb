# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Objects::Lesson do
  describe ".build_from" do
    subject { described_class.build_from(data) }

    let(:data) do
      {
        "subject" => "science",
        "grade" => "7",
        "unit-id" => "u1",
        "section-number" => "2",
        "lesson-number" => "3",
        "lesson-title" => "Exploring Ecosystems",
        "lesson-label" => "required",
        "lesson-type" => "core",
        "estimated-time" => "2 Class Periods",
        "standards" => "MS-LS2-1, MS-LS2-2",
        "description" => "<p>In this lesson, we explore ecosystems.</p>",
        "vocabulary" => "ecosystem, biome, habitat",
        "lms-enabled" => "Yes",
        "lms-summary" => "Explore ecosystems"
      }
    end

    it "coerces types and transforms keys" do
      expect(subject.grade).to eq 7
      expect(subject.section_number).to eq 2
      expect(subject.lesson_number).to eq 3
      expect(subject.lms_enabled).to be true
      expect(subject.unit_id).to eq "u1"
      expect(subject.lesson_title).to eq "Exploring Ecosystems"
      expect(subject.lesson_type).to eq "core"
      expect(subject.estimated_time).to eq "2 Class Periods"
      expect(subject.standards).to eq "MS-LS2-1, MS-LS2-2"
      expect(subject.description).to eq "<p>In this lesson, we explore ecosystems.</p>"
      expect(subject.vocabulary).to eq "ecosystem, biome, habitat"
    end

    context "when estimated-time and vocabulary are absent" do
      before do
        data.delete("estimated-time")
        data.delete("vocabulary")
      end

      it "defaults to blank strings" do
        expect(subject.estimated_time).to eq ""
        expect(subject.vocabulary).to eq ""
      end
    end

    context "when lms-enabled is No" do
      before { data["lms-enabled"] = "No" }

      it "coerces to false" do
        expect(subject.lms_enabled).to be false
      end
    end
  end
end
