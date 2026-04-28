# frozen_string_literal: true

require "rails_helper"

describe DocumentPresenter do
  let(:document) do
    create(:document, metadata: {
      "lesson_title" => "Introduction to Fractions",
      "grade" => "3",
      "unit_id" => "1",
      "section_number" => "1",
      "lesson_number" => "5",
      "subject" => "math"
    })
  end
  let(:presenter) { described_class.new(document) }

  describe "#gdoc_header" do
    context "when lesson_title is present" do
      it "returns 2D array with title placeholder and value" do
        result = presenter.gdoc_header

        expect(result).to eq([
          ["{title}"],
          ["Introduction to Fractions"]
        ])
      end
    end

    context "when lesson_title is blank" do
      let(:document) do
        create(:document, metadata: {
          "lesson_title" => "",
          "grade" => "3",
          "unit_id" => "1",
          "section_number" => "1",
          "lesson_number" => "5",
          "subject" => "math"
        })
      end

      it "returns empty string for title" do
        result = presenter.gdoc_header

        expect(result).to eq([
          ["{title}"],
          [""]
        ])
      end
    end
  end

  describe "integration with Google::ScriptService" do
    it "provides compatible format for ScriptService#parameters" do
      header = presenter.gdoc_header

      expect(header).to be_an(Array)
      expect(header.size).to eq(2)
      expect(header.all? { |row| row.is_a?(Array) }).to be true
    end
  end
end
