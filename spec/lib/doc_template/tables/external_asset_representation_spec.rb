# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tables::ExternalAssetRepresentation do
  let(:table) { described_class.new }
  let(:html) { HtmlSanitizer.sanitize(data) }
  let(:fragment) { Nokogiri::HTML.fragment html }

  describe "#parse" do
    subject { table.parse fragment }

    context "table with headers" do
      let(:data) { file_fixture("tables/external-asset-representation-metadata.html").read }

      it "fetches URL fields" do
        expect(subject.data["pdf"]).to eq "https://www.somematerial.pdf"
        expect(subject.data["slides"]).to eq "https://www.somematerial.pptx"
        expect(subject.data["video"]).to eq "https://www.example.com/video"
        expect(subject.data["webpage"]).to eq "https://www.example.com"
      end

      it "handles blank fields" do
        expect(subject.data["doc"]).to eq ""
        expect(subject.data["sheet"]).to eq ""
        expect(subject.data["form"]).to eq ""
      end

      it "marks table as existing" do
        expect(subject.table_exist?).to be true
      end
    end

    context "when table is missing" do
      let(:data) { "<html><body><p>no table here</p></body></html>" }

      it "does not mark table as existing" do
        expect(subject.table_exist?).to be false
      end
    end
  end

  describe "validation" do
    before { table.parse fragment }

    subject { table.errors }

    context "with valid metadata" do
      let(:data) { file_fixture("tables/external-asset-representation-metadata.html").read }

      it { is_expected.to be_empty }
    end

    context "with invalid URL" do
      let(:data) do
        <<~HTML
          <table>
            <tr><td colspan="2">external-asset-representation-metadata</td></tr>
            <tr><td>pdf</td><td>not-a-url</td></tr>
          </table>
        HTML
      end

      it { is_expected.to include("Invalid pdf URL: 'not-a-url'") }
    end
  end
end
