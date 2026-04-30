# frozen_string_literal: true

require "rails_helper"

describe Admin::SectionsQuery do
  describe "#call" do
    let(:base_params) do
      {
        subject: nil,
        grade: nil,
        grades: nil,
        unit_id: nil,
        section_number: nil,
        search_term: nil,
        sort_by: nil
      }
    end
    let(:query_params) { base_params }
    let(:query_struct) { Struct.new(*query_params.keys, keyword_init: true).new(query_params) }

    before do
      create(:resource, curriculum_type: "section", title: "Expressions", metadata: { subject: "math", grade: "6", unit: "m6u1a", unit_id: "m6u1a", section: "2", section_number: "2" })
      create(:resource, curriculum_type: "section", title: "Equations", metadata: { subject: "math", grade: "7", unit: "m7u1a", unit_id: "m7u1a", section: "1", section_number: "1" })
    end

    subject(:results) { described_class.call(query_struct) }

    it "returns section resources" do
      expect(results).to all(be_section)
    end

    context "with unit_id filter" do
      let(:query_params) { base_params.merge(unit_id: "m6u1a") }

      it "filters by unit_id" do
        expect(results.map { |r| r.metadata["unit_id"] }).to eq(["m6u1a"])
      end
    end

    context "with section_number filter" do
      let(:query_params) { base_params.merge(section_number: "1") }

      it "filters by section_number" do
        expect(results.map { |r| r.metadata["section_number"] }).to eq(["1"])
      end
    end

    context "with search_term filter" do
      let(:query_params) { base_params.merge(search_term: "Equation") }

      it "filters by title" do
        expect(results.map(&:title)).to eq(["Equations"])
      end
    end
  end
end
