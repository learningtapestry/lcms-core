# frozen_string_literal: true

require "rails_helper"

describe DocumentPresenter do
  let(:document) do
    create(:document, metadata: {
      "cc_attribution" => "CC BY-NC-SA 4.0",
      "title" => "Introduction to Fractions",
      "grade" => "3",
      "unit" => "1",
      "lesson" => "5",
      "subject" => "math"
    })
  end
  let(:presenter) { described_class.new(document) }

  describe "#gdoc_footer" do
    context "when cc_attribution is present" do
      it "returns 2D array with attribution placeholder and value" do
        result = presenter.gdoc_footer

        expect(result).to eq([
          ["{attribution}"],
          ["CC BY-NC-SA 4.0"]
        ])
      end
    end

    context "when cc_attribution is blank" do
      let(:document) do
        create(:document, metadata: {
          "title" => "Test Document",
          "cc_attribution" => "",
          "grade" => "3",
          "unit" => "1",
          "lesson" => "5",
          "subject" => "math"
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

    context "when cc_attribution is nil" do
      let(:document) do
        create(:document, metadata: {
          "title" => "Test Document",
          "grade" => "3",
          "unit" => "1",
          "lesson" => "5",
          "subject" => "math"
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
    context "when title is present" do
      it "returns 2D array with title placeholder and value" do
        result = presenter.gdoc_header

        expect(result).to eq([
          ["{title}"],
          ["Introduction to Fractions"]
        ])
      end
    end

    context "when title is blank" do
      let(:document) do
        create(:document, metadata: {
          "title" => "",
          "grade" => "3",
          "unit" => "1",
          "lesson" => "5",
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
