# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Objects::Unit do
  describe "defaults" do
    subject(:unit) { described_class.new }

    it "defaults string attributes to empty string" do
      %i(
        acknowledgements
        copyright
        course
        description
        grade
        license
        unit_id
        unit_materials
        unit_title
        unit_title_spanish
        unit_topic
        unit_topic_spanish
      ).each do |attr|
        expect(unit.public_send(attr)).to eq("")
      end
    end

    it "defaults material ids to an empty array" do
      expect(unit.material_ids).to eq([])
    end

    it "defaults subject to SUBJECT_DEFAULT" do
      expect(unit.subject).to eq(SUBJECT_DEFAULT)
    end
  end

  describe ".build_from" do
    let(:data) do
      {
        "Subject" => "math",
        "Grade" => "6",
        "Course" => "Algebra",
        "Unit-ID" => "M6U1A",
        "Unit-Title" => "Expressions and Equations",
        "Unit-Title-Spanish" => "Expresiones y ecuaciones",
        "Unit-Topic" => "Variable relationships",
        "Unit-Topic-Spanish" => "Relaciones entre variables",
        "Description" => "<p>Unit description</p>",
        "Copyright" => "Learning Tapestry",
        "License" => "CC BY-NC",
        "Acknowledgements" => "<p>Thanks</p>",
        "Material-Ids" => [1, 2]
      }
    end

    subject(:unit) { described_class.build_from(data) }

    it "maps metadata keys to unit attributes" do
      expect(unit.subject).to eq("math")
      expect(unit.grade).to eq("6")
      expect(unit.course).to eq("Algebra")
      expect(unit.unit_id).to eq("M6U1A")
      expect(unit.unit_title).to eq("Expressions and Equations")
      expect(unit.unit_title_spanish).to eq("Expresiones y ecuaciones")
      expect(unit.unit_topic).to eq("Variable relationships")
      expect(unit.unit_topic_spanish).to eq("Relaciones entre variables")
      expect(unit.description).to eq("<p>Unit description</p>")
      expect(unit.copyright).to eq("Learning Tapestry")
      expect(unit.license).to eq("CC BY-NC")
      expect(unit.acknowledgements).to eq("<p>Thanks</p>")
      expect(unit.material_ids).to eq([1, 2])
    end
  end
end
