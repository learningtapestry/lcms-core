# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tables::Material do
  let(:table) { described_class.new }
  let(:html) { HtmlSanitizer.sanitize(data) }
  let(:fragment) { Nokogiri::HTML.fragment html }

  describe "#parse" do
    subject { table.parse fragment }

    context "table with headers" do
      let(:data) { file_fixture("tables/material-metadata-theader.html").read }

      include_examples "removes metadata table"

      it "fetching all fields" do
        expect(subject.data["subject"]).to eq "ela"
        expect(subject.data["grade"]).to eq "7"
        expect(subject.data["material-id"]).to eq "7A24.AK.MAY10"
        expect(subject.data["material-type"]).to eq "AK"
        expect(subject.data["material-title"]).to eq "Ashoka Reading (Teacher Version)"
        expect(subject.data["material-title-spanish"]).to eq "Lectura de Ashoka"
        expect(subject.data["language"]).to eq "English"
        expect(subject.data["material-order"]).to eq "1"
        expect(subject.data["name-date"]).to eq "Yes"
        expect(subject.data["orientation"]).to eq "P"
      end
    end
  end

  describe "validation" do
    before { table.parse fragment }

    subject { table.errors }

    context "with valid metadata" do
      let(:data) { file_fixture("tables/material-metadata-theader.html").read }

      it { is_expected.to be_empty }
    end

    context "when material-id is blank" do
      let(:data) do
        <<~HTML
          <table>
            <tr><td colspan="2">material-metadata</td></tr>
            <tr><td>material-id</td><td></td></tr>
            <tr><td>material-type</td><td>Handout</td></tr>
            <tr><td>material-title</td><td>Worksheet</td></tr>
            <tr><td>language</td><td>English</td></tr>
          </table>
        HTML
      end

      it { is_expected.to include("material-id is required") }
    end

    context "when language is blank" do
      let(:data) do
        <<~HTML
          <table>
            <tr><td colspan="2">material-metadata</td></tr>
            <tr><td>material-id</td><td>TEST.MAT.001</td></tr>
            <tr><td>material-type</td><td>Handout</td></tr>
            <tr><td>material-title</td><td>Worksheet</td></tr>
            <tr><td>language</td><td></td></tr>
          </table>
        HTML
      end

      it "defaults to English" do
        table.parse fragment
        expect(table.data["language"]).to eq "English"
      end

      it { is_expected.to be_empty }
    end

    context "when language is missing" do
      let(:data) do
        <<~HTML
          <table>
            <tr><td colspan="2">material-metadata</td></tr>
            <tr><td>material-id</td><td>TEST.MAT.001</td></tr>
            <tr><td>material-type</td><td>Handout</td></tr>
            <tr><td>material-title</td><td>Worksheet</td></tr>
          </table>
        HTML
      end

      it "defaults to English" do
        table.parse fragment
        expect(table.data["language"]).to eq "English"
      end

      it { is_expected.to be_empty }
    end

    context "with invalid language" do
      let(:data) do
        <<~HTML
          <table>
            <tr><td colspan="2">material-metadata</td></tr>
            <tr><td>material-id</td><td>TEST.MAT.001</td></tr>
            <tr><td>material-type</td><td>Handout</td></tr>
            <tr><td>material-title</td><td>Worksheet</td></tr>
            <tr><td>language</td><td>French</td></tr>
          </table>
        HTML
      end

      it { is_expected.to include(match(/Invalid language: 'French'/)) }
    end

    context "with invalid material-id format" do
      let(:data) do
        <<~HTML
          <table>
            <tr><td colspan="2">material-metadata</td></tr>
            <tr><td>material-id</td><td>TEST MAT 001</td></tr>
            <tr><td>material-type</td><td>Handout</td></tr>
            <tr><td>material-title</td><td>Worksheet</td></tr>
            <tr><td>language</td><td>English</td></tr>
          </table>
        HTML
      end

      it { is_expected.to include(match(/Invalid material-id: 'TEST MAT 001'/)) }
    end

    context "with negative material-order" do
      let(:data) do
        <<~HTML
          <table>
            <tr><td colspan="2">material-metadata</td></tr>
            <tr><td>material-id</td><td>TEST.MAT.001</td></tr>
            <tr><td>material-type</td><td>Handout</td></tr>
            <tr><td>material-title</td><td>Worksheet</td></tr>
            <tr><td>language</td><td>English</td></tr>
            <tr><td>material-order</td><td>-1</td></tr>
          </table>
        HTML
      end

      it { is_expected.to include(match(/Invalid material-order: '-1'/)) }
    end

    context "with invalid name-date" do
      let(:data) do
        <<~HTML
          <table>
            <tr><td colspan="2">material-metadata</td></tr>
            <tr><td>material-id</td><td>TEST.MAT.001</td></tr>
            <tr><td>material-type</td><td>Handout</td></tr>
            <tr><td>material-title</td><td>Worksheet</td></tr>
            <tr><td>language</td><td>English</td></tr>
            <tr><td>name-date</td><td>Maybe</td></tr>
          </table>
        HTML
      end

      it { is_expected.to include(match(/Invalid name-date: 'Maybe'/)) }
    end

    context "with invalid orientation" do
      let(:data) do
        <<~HTML
          <table>
            <tr><td colspan="2">material-metadata</td></tr>
            <tr><td>material-id</td><td>TEST.MAT.001</td></tr>
            <tr><td>material-type</td><td>Handout</td></tr>
            <tr><td>material-title</td><td>Worksheet</td></tr>
            <tr><td>language</td><td>English</td></tr>
            <tr><td>orientation</td><td>Sideways</td></tr>
          </table>
        HTML
      end

      it { is_expected.to include(match(/Invalid orientation: 'Sideways'/)) }
    end
  end
end
