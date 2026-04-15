# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Objects::Material do
  describe ".build_from" do
    it "builds a valid material" do
      obj = described_class.build_from(
        "material-id" => "TEST.MAT.001",
        "material-title" => "Worksheet",
        "material-type" => "handout",
        "language" => "English",
        "orientation" => "p"
      )
      expect(obj.material_title).to eq "Worksheet"
      expect(obj.material_type).to eq "handout"
    end

    context "orientation normalization" do
      it "normalizes l to landscape" do
        obj = described_class.build_from(
          "material-id" => "TEST.MAT.001",
          "material-type" => "handout",
          "material-title" => "Worksheet",
          "language" => "English",
          "orientation" => "l"
        )
        expect(obj.orientation).to eq "landscape"
      end

      it "normalizes p to portrait" do
        obj = described_class.build_from(
          "material-id" => "TEST.MAT.001",
          "material-type" => "handout",
          "material-title" => "Worksheet",
          "language" => "English",
          "orientation" => "p"
        )
        expect(obj.orientation).to eq "portrait"
      end

      it "normalizes landscape to landscape" do
        obj = described_class.build_from(
          "material-id" => "TEST.MAT.001",
          "material-type" => "handout",
          "material-title" => "Worksheet",
          "language" => "English",
          "orientation" => "landscape"
        )
        expect(obj.orientation).to eq "landscape"
      end

      it "defaults blank orientation to portrait" do
        obj = described_class.build_from(
          "material-id" => "TEST.MAT.001",
          "material-type" => "handout",
          "material-title" => "Worksheet",
          "language" => "English",
          "orientation" => ""
        )
        expect(obj.orientation).to eq "portrait"
      end
    end

    it "coerces material-order to integer" do
      obj = described_class.build_from(
        "material-id" => "TEST.MAT.001",
        "material-type" => "handout",
        "material-title" => "Worksheet",
        "language" => "English",
        "orientation" => "p",
        "material-order" => "3"
      )
      expect(obj.material_order).to eq 3
    end

    it "defaults blank material-order to 0" do
      obj = described_class.build_from(
        "material-id" => "TEST.MAT.001",
        "material-type" => "handout",
        "material-title" => "Worksheet",
        "language" => "English",
        "material-order" => ""
      )

      expect(obj.material_order).to eq 0
    end

    it "builds all new fields" do
      obj = described_class.build_from(
        "material-id" => "7A24.AK.MAY10",
        "material-type" => "handout",
        "material-title" => "Reading",
        "material-title-spanish" => "Lectura",
        "language" => "English",
        "material-order" => "1",
        "name-date" => "Yes",
        "attribution" => "Copyright 2026",
        "orientation" => "p"
      )
      expect(obj.material_id).to eq "7A24.AK.MAY10"
      expect(obj.material_type).to eq "handout"
      expect(obj.material_title).to eq "Reading"
      expect(obj.material_title_spanish).to eq "Lectura"
      expect(obj.language).to eq "English"
      expect(obj.material_order).to eq 1
      expect(obj.name_date).to eq true
      expect(obj.attribution).to eq "Copyright 2026"
    end
  end

  describe "defaults" do
    subject { described_class.new }

    it "defaults string attributes" do
      expect(subject.attribution).to eq ""
      expect(subject.grade).to eq ""
      expect(subject.language).to eq ""
      expect(subject.material_id).to eq ""
      expect(subject.material_title).to eq ""
      expect(subject.material_title_spanish).to eq ""
      expect(subject.material_type).to eq ""
      expect(subject.name_date).to eq false
    end

    it "defaults material_order to 0" do
      expect(subject.material_order).to eq 0
    end
  end
end
