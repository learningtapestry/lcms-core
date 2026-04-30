# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Objects::SectionMetadata do
  describe "defaults" do
    subject(:section) { described_class.new }

    it "defaults string attributes to empty string" do
      %i(description grade section_materials section_number section_title section_title_spanish unit_id).each do |attr|
        expect(section.public_send(attr)).to eq("")
      end
    end

    it "defaults material ids to an empty array" do
      expect(section.material_ids).to eq([])
    end

    it "defaults subject to SUBJECT_DEFAULT" do
      expect(section.subject).to eq(SUBJECT_DEFAULT)
    end
  end

  describe ".build_from" do
    let(:data) do
      {
        "Subject" => "math",
        "Grade" => "6",
        "Unit-ID" => "M6U1A",
        "Section-Number" => "2",
        "Section-Title" => "Expressions with Variables",
        "Section-Title-Spanish" => "Expresiones con variables",
        "Description" => "<p>Students write and evaluate expressions.</p>",
        "Material-Ids" => [1, 2]
      }
    end

    subject(:section) { described_class.build_from(data) }

    it "maps metadata keys to attributes" do
      expect(section.subject).to eq("math")
      expect(section.grade).to eq("6")
      expect(section.unit_id).to eq("M6U1A")
      expect(section.section_number).to eq("2")
      expect(section.section_title).to eq("Expressions with Variables")
      expect(section.section_title_spanish).to eq("Expresiones con variables")
      expect(section.description).to eq("<p>Students write and evaluate expressions.</p>")
      expect(section.material_ids).to eq([1, 2])
    end
  end
end
