# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Objects::Document do
  describe "defaults" do
    subject { described_class.new }

    it "defaults string attributes to empty string" do
      %i(cc_attribution description grade lesson lesson_objective lesson_standard
         materials preparation section standard teaser title unit).each do |attr|
        expect(subject.public_send(attr)).to eq("")
      end
    end

    it "defaults type to core" do
      expect(subject.type).to eq "core"
    end

    it "defaults subject to SUBJECT_DEFAULT" do
      expect(subject.subject).to eq SUBJECT_DEFAULT
    end
  end

  describe ".build_from" do
    let(:data) do
      {
        "Title" => "Lesson 1",
        "Grade" => "2",
        "Unit" => "M3",
        "Type" => "optional"
      }
    end

    subject { described_class.build_from(data) }

    it "populates attributes from data" do
      expect(subject.title).to eq "Lesson 1"
      expect(subject.grade).to eq "2"
      expect(subject.unit).to eq "M3"
      expect(subject.type).to eq "optional"
    end

    it "keeps defaults for missing attributes" do
      expect(subject.cc_attribution).to eq ""
      expect(subject.description).to eq ""
    end
  end
end
