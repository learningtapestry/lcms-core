# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Validators::LmsHierarchyValidator do
  describe "#validate" do
    subject { described_class.new(lesson_data, activity_data_list).validate }

    context "when lesson lms-enabled is Yes" do
      let(:lesson_data) { { "lms-enabled" => "Yes" } }
      let(:activity_data_list) { [{ "lms-enabled" => "Yes", "activity-title" => "Act 1" }] }

      it { is_expected.to be_empty }
    end

    context "when lesson lms-enabled is No and all activities are No" do
      let(:lesson_data) { { "lms-enabled" => "No" } }
      let(:activity_data_list) { [{ "lms-enabled" => "No", "activity-title" => "Act 1" }] }

      it { is_expected.to be_empty }
    end

    context "when lesson lms-enabled is No but activity is Yes" do
      let(:lesson_data) { { "lms-enabled" => "No" } }
      let(:activity_data_list) do
        [
          { "lms-enabled" => "No", "activity-title" => "Act 1" },
          { "lms-enabled" => "Yes", "activity-title" => "Act 2" }
        ]
      end

      it "returns error only for the offending activity" do
        expect(subject.size).to eq 1
        expect(subject.first).to match(/Activity 'Act 2'.*lms-enabled=Yes.*lesson has lms-enabled=No/)
      end
    end
  end
end
