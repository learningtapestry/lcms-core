# frozen_string_literal: true

require "rails_helper"

describe Admin::DocumentsQuery do
  describe "#call" do
    # Base params that include all fields the query might access
    let(:base_params) do
      {
        inactive: nil,
        only_failed: nil,
        search_term: nil,
        subject: nil,
        grade: nil,
        grades: nil,
        module: nil,
        unit: nil,
        broken_materials: nil,
        reimport_required: nil,
        sort_by: nil
      }
    end
    let(:query_params) { base_params }
    let(:query_struct) { Struct.new(*query_params.keys, keyword_init: true).new(query_params) }
    let(:scope) { double(ActiveRecord::Relation) }

    before do
      allow(Document).to receive(:all).and_return(scope)
      allow(scope).to receive(:actives).and_return(scope)
      allow(scope).to receive(:unscoped).and_return(scope)
      allow(scope).to receive(:order_by_curriculum).and_return(scope)
      allow(scope).to receive(:distinct).and_return(scope)
      allow(scope).to receive(:order).and_return(scope)
    end

    subject { described_class.call(query_struct) }

    context "with no filters" do
      it "returns active documents ordered by curriculum" do
        expect(scope).to receive(:actives).and_return(scope)
        expect(scope).to receive(:order_by_curriculum).and_return(scope)
        subject
      end
    end

    context "with inactive filter" do
      let(:query_params) { base_params.merge(inactive: "1") }

      it "returns unscoped documents" do
        expect(scope).to receive(:unscoped).and_return(scope)
        subject
      end
    end

    context "with only_failed filter" do
      let(:query_params) { base_params.merge(only_failed: "1") }

      it "filters by failed documents" do
        expect(scope).to receive(:failed).and_return(scope)
        subject
      end
    end

    context "with search_term filter" do
      let(:query_params) { base_params.merge(search_term: "test lesson") }

      it "filters by search term" do
        expect(scope).to receive(:filter_by_term).with("test lesson").and_return(scope)
        subject
      end
    end

    context "with subject filter" do
      let(:query_params) { base_params.merge(subject: "ela") }

      it "filters by subject" do
        expect(scope).to receive(:filter_by_subject).with("ela").and_return(scope)
        subject
      end
    end

    context "with grade filter" do
      let(:query_params) { base_params.merge(grade: "grade 2") }

      it "filters by grade" do
        expect(scope).to receive(:filter_by_grade).with("grade 2").and_return(scope)
        subject
      end
    end

    context "with grades array filter" do
      let(:query_params) { base_params.merge(grades: ["grade 1", "grade 2"]) }

      it "filters by multiple grades" do
        expect(scope).to receive(:where_grade).with(["grade 1", "grade 2"]).and_return(scope)
        subject
      end
    end

    context "with module filter" do
      let(:query_params) { base_params.merge(module: "module 1") }

      it "filters by module" do
        expect(scope).to receive(:filter_by_module).with("module 1").and_return(scope)
        subject
      end
    end

    context "with unit filter" do
      let(:query_params) { base_params.merge(unit: "unit 1") }

      it "filters by unit" do
        expect(scope).to receive(:filter_by_unit).with("unit 1").and_return(scope)
        subject
      end
    end

    context "with broken_materials filter" do
      let(:query_params) { base_params.merge(broken_materials: "1") }

      it "filters by broken materials" do
        expect(scope).to receive(:with_broken_materials).and_return(scope)
        subject
      end
    end

    context "with reimport_required filter" do
      let(:query_params) { base_params.merge(reimport_required: "1") }

      it "filters by updated materials requiring reimport" do
        expect(scope).to receive(:with_updated_materials).and_return(scope)
        subject
      end
    end

    context "with sort_by last_update" do
      let(:query_params) { base_params.merge(sort_by: "last_update") }

      it "orders by updated_at desc" do
        expect(scope).to receive(:order).with(updated_at: :desc).and_return(scope)
        subject
      end
    end

    context "with pagination" do
      it "paginates results" do
        expect(scope).to receive(:paginate).with(page: 2).and_return(scope)
        described_class.call(query_struct, page: 2)
      end
    end
  end
end
