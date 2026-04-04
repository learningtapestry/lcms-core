# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Objects::Material do
  describe ".build_from" do
    it "raises when type is blank" do
      expect { described_class.build_from("Title" => "Test") }.to raise_error(RuntimeError, /Type field is empty/)
    end

    it "builds a valid material" do
      obj = described_class.build_from("Title" => "Worksheet", "Type" => "student", "Orientation" => "p")
      expect(obj.title).to eq "Worksheet"
      expect(obj.type).to eq "student"
    end

    context "orientation normalization" do
      it "normalizes l to landscape" do
        obj = described_class.build_from("Type" => "student", "Orientation" => "l")
        expect(obj.orientation).to eq "landscape"
      end

      it "normalizes p to portrait" do
        obj = described_class.build_from("Type" => "student", "Orientation" => "p")
        expect(obj.orientation).to eq "portrait"
      end

      it "normalizes landscape to landscape" do
        obj = described_class.build_from("Type" => "student", "Orientation" => "landscape")
        expect(obj.orientation).to eq "landscape"
      end

      it "defaults blank orientation to portrait" do
        obj = described_class.build_from("Type" => "student", "Orientation" => "")
        expect(obj.orientation).to eq "portrait"
      end
    end

    it "coerces activity to integer" do
      obj = described_class.build_from("Type" => "student", "Orientation" => "p", "Activity" => "3")
      expect(obj.activity).to eq 3
    end
  end

  describe "defaults" do
    subject { described_class.new }

    it "defaults string attributes" do
      expect(subject.cc_attribution).to eq ""
      expect(subject.grade).to eq ""
      expect(subject.header_footer).to eq "yes"
      expect(subject.name_date).to eq "no"
      expect(subject.show_title).to eq "yes"
    end
  end
end
