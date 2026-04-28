# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tables::LmsMaterials do
  let(:table) { described_class.new }
  let(:html) { HtmlSanitizer.sanitize(data) }
  let(:fragment) { Nokogiri::HTML.fragment html }

  describe "#parse" do
    subject { table.parse fragment }

    context "when lms-materials table is present" do
      let(:data) { file_fixture("tables/lms-materials.html").read }

      it "extracts entries and removes the table" do
        expect(subject).to eq([
          { "material-id" => "mat-handout-1", "access-type" => "individual-submission" },
          { "material-id" => "mat-reference-1", "access-type" => "view-only" }
        ])
        expect(fragment.to_html).not_to include("lms-materials")
      end
    end

    context "when lms-materials table is absent" do
      let(:data) { "<html><body><p>No table here</p></body></html>" }

      it { is_expected.to eq [] }
    end
  end
end
