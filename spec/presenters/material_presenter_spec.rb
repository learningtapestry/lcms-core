# frozen_string_literal: true

require "rails_helper"

describe MaterialPresenter do
  let(:material) do
    create(:material, metadata: {
      "attribution" => "CC BY 4.0",
      "material_id" => "TEST.MAT.001",
      "material_title" => "Student Worksheet",
      "material_type" => "handout",
      "language" => "English",
      "orientation" => "portrait"
    })
  end
  let(:presenter) { described_class.new(material) }

  describe "#gdoc_footer" do
    context "when attribution is present" do
      it "returns 2D array with attribution placeholder and value" do
        result = presenter.gdoc_footer

        expect(result).to eq([
          ["{attribution}"],
          ["CC BY 4.0"]
        ])
      end
    end

    context "when attribution is blank" do
      let(:material) do
        create(:material, metadata: {
          "attribution" => "",
          "material_id" => "TEST.MAT.001",
          "material_title" => "Student Worksheet",
          "material_type" => "handout",
          "language" => "English",
          "orientation" => "portrait"
        })
      end

      it "returns default attribution text" do
        result = presenter.gdoc_footer

        expect(result).to eq([
          ["{attribution}"],
          ["Copyright attribution here"]
        ])
      end
    end

    context "when attribution is nil" do
      let(:material) do
        create(:material, metadata: {
          "material_id" => "TEST.MAT.001",
          "material_title" => "Student Worksheet",
          "material_type" => "handout",
          "language" => "English",
          "orientation" => "portrait"
        })
      end

      it "returns default attribution text" do
        result = presenter.gdoc_footer

        expect(result).to eq([
          ["{attribution}"],
          ["Copyright attribution here"]
        ])
      end
    end
  end

  describe "#gdoc_header" do
    context "when material_title is present in metadata" do
      it "returns 2D array with title placeholder and value" do
        result = presenter.gdoc_header

        expect(result).to eq([
          ["{title}"],
          ["Student Worksheet"]
        ])
      end
    end
  end

  describe "#orientation" do
    context "when orientation is set in metadata" do
      let(:material) do
        create(:material, metadata: {
          "material_id" => "TEST.MAT.001",
          "material_title" => "Student Worksheet",
          "material_type" => "handout",
          "language" => "English",
          "orientation" => "landscape"
        })
      end

      it "returns orientation from metadata" do
        expect(presenter.orientation).to eq("landscape")
      end
    end

    context "when orientation is set to 'l' in metadata" do
      let(:material) do
        create(:material, metadata: {
          "material_id" => "TEST.MAT.001",
          "material_title" => "Student Worksheet",
          "material_type" => "handout",
          "language" => "English",
          "orientation" => "l"
        })
      end

      it "normalizes to landscape" do
        expect(presenter.orientation).to eq("landscape")
      end
    end

    context "when orientation is set to 'p' in metadata" do
      let(:material) do
        create(:material, metadata: {
          "material_id" => "TEST.MAT.001",
          "material_title" => "Student Worksheet",
          "material_type" => "handout",
          "language" => "English",
          "orientation" => "p"
        })
      end

      it "normalizes to portrait" do
        expect(presenter.orientation).to eq("portrait")
      end
    end
  end

  describe "integration with Google::ScriptService" do
    it "provides compatible format for ScriptService#parameters" do
      footer = presenter.gdoc_footer
      header = presenter.gdoc_header

      expect(footer).to be_an(Array)
      expect(footer.size).to eq(2)
      expect(footer.all? { |row| row.is_a?(Array) }).to be true

      expect(header).to be_an(Array)
      expect(header.size).to eq(2)
      expect(header.all? { |row| row.is_a?(Array) }).to be true
    end
  end
end
