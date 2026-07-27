# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tags::ImageTag do
  let(:node) do
    html = Nokogiri::HTML original_content
    html.at_xpath("*//table/thead/tr[1]/td[1]")
  end
  let(:metadata) { { "grade" => "5", "unit" => "1", "subject" => "Math" } }
  let(:value) { "example_image" }
  let(:opts) { { value:, metadata: } }
  let(:original_content) do
    <<-HTML
      <table>
        <thead>
          <tr><td>[#{described_class::TAG_NAME}]</td></tr>
          <tr><td>Caption text</td></tr>
          <tr><td>Credit text</td></tr>
        </thead>
      </table>
    HTML
  end
  let(:tag) { described_class.new }
  subject { tag.parse(node, opts) }

  describe "#parse_table" do
    it "removes original node" do
      expect(subject.content).to_not include("[#{described_class::TAG_NAME}]")
    end

    it "substitues tag with image with caption" do
      expect(subject.content).to include("figcaption>Caption text</figcaption>")
    end

    it "defaults to centered, large layout" do
      expect(subject.content).to include("o-ld-image--center")
      expect(subject.content).to include("o-ld-image--large")
    end

    it "renders the credit row for centered images" do
      expect(subject.content).to include('class="o-ld-image__credit">Credit text')
    end

    it "builds the image src from the first token only" do
      expect(subject.content).to include("example_image.jpg")
    end
  end

  describe "alignment and size args" do
    context "when size is specified" do
      let(:value) { "example_image size=medium" }

      it "applies the size modifier" do
        expect(subject.content).to include("o-ld-image--medium")
      end

      it "still builds the src from the id only (ignores args)" do
        expect(subject.content).to include("example_image.jpg")
        expect(subject.content).not_to include("size=medium.jpg")
      end
    end

    %w(left right).each do |align|
      context "when aligned #{align}" do
        let(:value) { "example_image align=#{align}" }

        it "applies the #{align} float modifier" do
          expect(subject.content).to include("o-ld-image--#{align}")
        end

        it "suppresses the caption and credit (text wraps instead)" do
          expect(subject.content).not_to include("figcaption")
          expect(subject.content).not_to include("o-ld-image__credit")
        end
      end
    end

    context "when align is centered explicitly" do
      let(:value) { "example_image align=center size=small" }

      it "keeps the caption and credit" do
        expect(subject.content).to include("figcaption>Caption text</figcaption>")
        expect(subject.content).to include("o-ld-image__credit")
      end

      it "applies center and small modifiers" do
        expect(subject.content).to include("o-ld-image--center")
        expect(subject.content).to include("o-ld-image--small")
      end
    end

    context "when an unrecognized value is given" do
      let(:value) { "example_image align=sideways size=huge" }

      it "falls back to center/large defaults" do
        expect(subject.content).to include("o-ld-image--center")
        expect(subject.content).to include("o-ld-image--large")
      end
    end
  end
end
