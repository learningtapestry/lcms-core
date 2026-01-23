# frozen_string_literal: true

require "rails_helper"

describe UnitBundleInteractor do
  describe "#run" do
    let(:metadata) do
      { subject: "ela", grade: "grade 2", module: "module 1", unit: "unit 1" }
    end

    let(:unit) { create(:resource, metadata: metadata) }

    subject(:interactor) { described_class.call(unit) }

    it "is successful" do
      expect(interactor).to be_success
    end

    it "sets the unit attribute" do
      expect(interactor.unit).to eq(unit)
    end

    context "when materials exist with matching metadata" do
      let!(:matching_material) { create(:material, metadata: metadata) }
      let!(:another_matching_material) { create(:material, metadata: metadata) }

      it "returns materials as MaterialPresenter instances" do
        expect(interactor.materials).to all(be_a(MaterialPresenter))
      end

      it "includes materials with matching metadata" do
        material_ids = interactor.materials.map(&:id)
        expect(material_ids).to contain_exactly(matching_material.id, another_matching_material.id)
      end
    end

    context "when materials have different metadata" do
      let!(:matching_material) { create(:material, metadata: metadata) }
      let!(:different_subject_material) do
        create(:material, metadata: metadata.merge(subject: "math"))
      end
      let!(:different_grade_material) do
        create(:material, metadata: metadata.merge(grade: "grade 3"))
      end
      let!(:different_module_material) do
        create(:material, metadata: metadata.merge(module: "module 2"))
      end
      let!(:different_unit_material) do
        create(:material, metadata: metadata.merge(unit: "unit 2"))
      end

      it "only includes materials with exact metadata match" do
        material_ids = interactor.materials.map(&:id)
        expect(material_ids).to contain_exactly(matching_material.id)
      end

      it "excludes materials with different subject" do
        material_ids = interactor.materials.map(&:id)
        expect(material_ids).not_to include(different_subject_material.id)
      end

      it "excludes materials with different grade" do
        material_ids = interactor.materials.map(&:id)
        expect(material_ids).not_to include(different_grade_material.id)
      end

      it "excludes materials with different module" do
        material_ids = interactor.materials.map(&:id)
        expect(material_ids).not_to include(different_module_material.id)
      end

      it "excludes materials with different unit" do
        material_ids = interactor.materials.map(&:id)
        expect(material_ids).not_to include(different_unit_material.id)
      end
    end

    context "when no materials exist with matching metadata" do
      let!(:unrelated_material) do
        create(:material, metadata: { subject: "math", grade: "grade 5", module: "module 3", unit: "unit 4" })
      end

      it "returns an empty collection" do
        expect(interactor.materials).to be_empty
      end
    end

    context "when materials have partial metadata match" do
      let!(:partial_match_material) do
        create(:material, metadata: { subject: "ela", grade: "grade 2" })
      end

      it "excludes materials with partial metadata match" do
        expect(interactor.materials).to be_empty
      end
    end
  end
end
