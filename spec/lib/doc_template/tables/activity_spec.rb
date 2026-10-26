# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tables::Activity do
  let(:table) { described_class.new }
  let(:html) { HtmlSanitizer.sanitize(data) }
  let(:fragment) { Nokogiri::HTML.fragment html }

  describe "#parse" do
    let(:data) { file_fixture("tables/activity-metadata-3activities.html").read }

    subject { table.parse fragment }

    include_examples "removes metadata table"

    it "processed 3 acivities" do
      expect(subject.size).to eq 3
    end

    it "processed data from acivities" do
      subject.each_with_index do |activity, idx|
        expect(activity["number"].to_i).to eq idx + 1
        expect(activity["class-configuration"]).to eq "Whole class"
      end
    end
  end

  describe "material rows" do
    let(:data) do
      <<~HTML
        <table><tbody>
          <tr><td colspan="2"><p>activity-metadata</p></td></tr>
          <tr><td><p>activity-title</p></td><td><p>Explore</p></td></tr>
          <tr><td><p>activity-materials-class</p></td>
              <td><p><span style="font-style:italic">Wonder Walkers</span><span> by Micha Archer, Chart paper</span></p></td></tr>
        </tbody></table>
      HTML
    end

    subject(:activity) { described_class.parse(fragment).first }

    # The Materials table needs the authored formatting; everything else keeps
    # reading the plain text.
    it "keeps the plain text and adds the cell HTML under <key>-html" do
      expect(activity["activity-materials-class"]).to eq "Wonder Walkers by Micha Archer, Chart paper"
      expect(activity["activity-materials-class-html"]).to include(%(<span style="font-style:italic">Wonder Walkers</span>))
    end

    it "does not add HTML copies for other rows" do
      expect(activity).not_to have_key("activity-title-html")
    end
  end

  describe "validation" do
    before { table.parse fragment }

    subject { table.errors }

    context "with valid metadata" do
      let(:data) { file_fixture("tables/activity-metadata-valid.html").read }

      it { is_expected.to be_empty }
    end

    context "with invalid student-grouping" do
      let(:data) { file_fixture("tables/activity-metadata-invalid-grouping.html").read }

      it { is_expected.to include(match(/invalid student-grouping.*everyone/)) }
    end

    context "with invalid lms-type" do
      let(:data) { file_fixture("tables/activity-metadata-invalid-lms-type.html").read }

      it { is_expected.to include(match(/invalid lms-type.*homework/)) }
    end

    context "when lms-enabled is No and lms fields are filled" do
      let(:data) { file_fixture("tables/activity-metadata-lms-disabled-with-title.html").read }

      it { is_expected.to include(match(/lms-title should be blank/)) }
    end

    context "with valid lms-materials access-type" do
      let(:data) { file_fixture("tables/activity-metadata-with-lms-materials-valid.html").read }

      it { is_expected.to be_empty }
    end

    context "with invalid lms-materials access-type" do
      let(:data) { file_fixture("tables/activity-metadata-with-lms-materials-invalid.html").read }

      it { is_expected.to include(match(/invalid access-type.*full-access/)) }
    end
  end
end
