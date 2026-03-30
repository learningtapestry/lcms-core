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
        "standards" => "MS-LS2-1, MS-LS2-2",
        "description" => "<p>In this lesson, we explore ecosystems.</p>",
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
      expect(subject.standards).to eq "MS-LS2-1, MS-LS2-2"
      expect(subject.description).to eq "<p>In this lesson, we explore ecosystems.</p>"
    end

    context "when lms-enabled is No" do
      before { data["lms-enabled"] = "No" }

      it "coerces to false" do
        expect(subject.lms_enabled).to be false
      end
    end
  end
end
