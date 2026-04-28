# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tables::Lesson do
  let(:table) { described_class.new }
  let(:html) { HtmlSanitizer.sanitize(data) }
  let(:fragment) { Nokogiri::HTML.fragment html }

  describe "#parse" do
    subject { table.parse fragment }

    shared_examples "process metadata table" do
      include_examples "removes metadata table"

      it { expect(subject.data["lesson-type"]).to eq "lesson" }
    end

    context "regular header" do
      let(:data) { file_fixture("tables/lesson-metadata.html").read }

      include_examples "process metadata table"
    end

    context "header with spans" do
      let(:data) { file_fixture("tables/lesson-metadata-2spans.html").read }

      include_examples "process metadata table"
    end

    context "2 paragraphs header with space" do
      let(:data) { file_fixture("tables/lesson-metadata-2paragpraphs.html").read }

      include_examples "process metadata table"
    end
  end

  describe "validation" do
    before { table.parse fragment }

    subject { table.errors }

    context "with valid metadata" do
      let(:data) { file_fixture("tables/lesson-metadata-valid.html").read }

      it { is_expected.to be_empty }
    end

    context "with invalid lesson-label" do
      let(:data) { file_fixture("tables/lesson-metadata-invalid-label.html").read }

      it { is_expected.to include(match(/Invalid lesson-label.*important/)) }
    end

    context "when lms-enabled is No and lms-summary is filled" do
      let(:data) { file_fixture("tables/lesson-metadata-lms-disabled-with-summary.html").read }

      it { is_expected.to include(match(/lms-summary should be blank/)) }
    end
  end
end
