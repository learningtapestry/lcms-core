# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tables::LessonPrep do
  let(:table) { described_class.new }

  describe "#parse" do
    let(:html) { HtmlSanitizer.sanitize(data) }
    let(:fragment) { Nokogiri::HTML.fragment html }

    subject { table.parse fragment }

    context "when lesson-prep table is present" do
      let(:data) { file_fixture("tables/lesson-prep.html").read }

      include_examples "removes metadata table"

      it "extracts lesson-prep-time" do
        expect(subject.data["lesson-prep-time"]).to eq "15"
      end

      it "extracts lesson-prep-directions" do
        expect(subject.data["lesson-prep-directions"]).to include("Review student notebooks")
      end
    end

    context "when lesson-prep table is absent" do
      let(:data) { "<html><body><p>No table here</p></body></html>" }

      it "returns empty data" do
        expect(subject.data).to be_empty
      end
    end
  end
end
