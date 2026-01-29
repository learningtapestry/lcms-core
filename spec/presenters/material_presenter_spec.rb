# frozen_string_literal: true

require "rails_helper"

describe MaterialPresenter do
  let(:material) do
    create(:material, metadata: {
      "cc_attribution" => "CC BY 4.0",
      "title" => "Student Worksheet",
      "type" => "handout",
      "orientation" => "portrait"
    })
  end
  let(:presenter) { described_class.new(material) }

  describe "#gdoc_footer" do
    context "when cc_attribution is present" do
      it "returns 2D array with attribution placeholder and value" do
        result = presenter.gdoc_footer

        expect(result).to eq([
          ["{attribution}"],
          ["CC BY 4.0"]
        ])
      end
    end

    context "when cc_attribution is blank" do
      let(:material) do
        create(:material, metadata: {
          "cc_attribution" => "",
          "type" => "handout",
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

    context "when cc_attribution is nil" do
      let(:material) do
        create(:material, metadata: {
          "type" => "handout",
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
    context "when title is present in metadata" do
      it "returns 2D array with title placeholder and value" do
        result = presenter.gdoc_header

        expect(result).to eq([
          ["{title}"],
          ["Student Worksheet"]
        ])
      end
    end

    context "when title is blank in metadata" do
      let(:material) do
        create(:material, metadata: {
          "title" => "",
          "type" => "handout",
          "orientation" => "portrait"
        })
      end

      it "returns default title" do
        result = presenter.gdoc_header

        expect(result).to eq([
          ["{title}"],
          ["Material"]
        ])
      end
    end

    context "when title is nil in metadata" do
      let(:material) do
        create(:material, metadata: {
          "type" => "handout",
          "orientation" => "portrait"
        })
      end

      it "returns default title" do
        result = presenter.gdoc_header

        expect(result).to eq([
          ["{title}"],
          ["Material"]
        ])
      end
    end
  end

  describe "#orientation" do
    context "when orientation is set in metadata" do
      let(:material) do
        create(:material, metadata: {
          "type" => "handout",
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
          "type" => "handout",
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
          "type" => "handout",
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
