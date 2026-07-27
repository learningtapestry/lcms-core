# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tags::MaterialTag do
  let(:tag) { described_class.new }
  let(:fragment) { Nokogiri::HTML.fragment(html) }
  let(:node) { fragment.at_xpath(".//p") }

  describe "#parse" do
    let(:html) { %(<p>provide copies of <span>[material: #{identifier}]</span>.</p>) }
    let(:identifier) { "10s.10.gg.l7.worksheet01" }

    subject(:parsed) { tag.parse(node, value: identifier) }

    context "when the material exists" do
      let!(:material) { create(:material, identifier: identifier) }

      it "renders the material as plain text, not a link" do
        expect(parsed.content).to include(%(<span class="o-ld-material">#{identifier}</span>))
        expect(parsed.content).not_to include("href")
      end

      it "leaves no errors" do
        expect(parsed.errors).to be_empty
      end
    end

    context "when the material has an authored title" do
      let!(:material) do
        create(:material, identifier: identifier, metadata: { "material-title" => "Lesson 7 Slides" })
      end

      it "uses the material title as the visible text" do
        expect(parsed.content).to include(%(<span class="o-ld-material">Lesson 7 Slides</span>))
        expect(parsed.content).not_to include("href")
      end
    end

    context "when the material does not exist" do
      it "renders a red badge with the identifier" do
        expect(parsed.content).to include("badge text-bg-danger")
        expect(parsed.content).to include("Unknown material: #{identifier}")
      end

      it "does not report an error" do
        expect(parsed.errors).to be_empty
      end
    end
  end
end
