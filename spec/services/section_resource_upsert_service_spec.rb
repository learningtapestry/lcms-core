# frozen_string_literal: true

require "rails_helper"

describe SectionResourceUpsertService do
  describe ".call" do
    let(:metadata) do
      {
        "subject" => "math",
        "grade" => "6",
        "unit_id" => "m6u1a",
        "section_number" => "2",
        "section_title" => "Expressions with Variables",
        "description" => "<p>Students write and evaluate expressions.</p>",
        "material_ids" => [1, 2]
      }
    end
    let(:source_link_data) do
      {
        "source" => {
          "gdoc" => {
            "url" => "https://docs.google.com/document/d/section-file-id"
          }
        }
      }
    end

    subject(:resource) { described_class.call(metadata:, source_link_data:) }

    it "creates a section resource" do
      expect(resource).to be_a(Resource)
      expect(resource).to be_section
    end

    it "stores section metadata on the resource" do
      expect(resource.metadata).to include(
        "subject" => "math",
        "grade" => "6",
        "unit" => "m6u1a",
        "unit_id" => "m6u1a",
        "section" => "2",
        "section_number" => "2",
        "section_title" => "Expressions with Variables"
      )
    end

    it "stores source link data" do
      expect(resource.links.dig("source", "gdoc", "url")).to eq("https://docs.google.com/document/d/section-file-id")
    end

    it "is idempotent: re-running with the same metadata does not create duplicates" do
      first = described_class.call(metadata:, source_link_data:)
      second = described_class.call(metadata:, source_link_data:)
      expect(second.id).to eq(first.id)
      expect(Resource.sections.count).to eq(1)
    end

    it "does not clobber existing material_ids when re-imported metadata omits them" do
      first = described_class.call(metadata:, source_link_data:)
      first.update!(metadata: first.metadata.merge("material_ids" => [42, 99]))

      described_class.call(metadata: metadata.except("material_ids"), source_link_data:)
      expect(first.reload.metadata["material_ids"]).to eq([42, 99])
    end
  end
end
