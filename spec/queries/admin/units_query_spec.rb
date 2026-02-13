# frozen_string_literal: true

require "rails_helper"

describe Admin::UnitsQuery do
  describe "#call" do
    # Base params that include all fields the query might access
    let(:base_params) do
      {
        subject: nil,
        grade: nil,
        grades: nil,
        module: nil,
        sort_by: nil
      }
    end
    let(:query_params) { base_params }
    let(:query_struct) { Struct.new(*query_params.keys, keyword_init: true).new(query_params) }
    let(:scope) { double(ActiveRecord::Relation) }

    before do
      allow(Resource).to receive(:units).and_return(scope)
      allow(scope).to receive(:all).and_return(scope)
      allow(scope).to receive(:ordered).and_return(scope)
      allow(scope).to receive(:distinct).and_return(scope)
      allow(scope).to receive(:order).and_return(scope)
    end

    subject { described_class.call(query_struct) }

    context "with no filters" do
      it "returns all units ordered by curriculum" do
        expect(Resource).to receive(:units).and_return(scope)
        expect(scope).to receive(:ordered).and_return(scope)
        subject
      end
    end

    context "with subject filter" do
      let(:query_params) { base_params.merge(subject: "math") }

      it "filters by subject" do
        expect(scope).to receive(:filter_by_subject).with("math").and_return(scope)
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

      context "when grades array contains nils" do
        let(:query_params) { base_params.merge(grades: ["grade 1", nil, "grade 2"]) }

        it "compacts the array before filtering" do
          expect(scope).to receive(:where_grade).with(["grade 1", "grade 2"]).and_return(scope)
          subject
        end
      end
    end

    context "with sort_by last_update" do
      let(:query_params) { base_params.merge(sort_by: "last_update") }

      it "orders by updated_at desc" do
        expect(scope).to receive(:order).with(updated_at: :desc).and_return(scope)
        subject
      end
    end

    context "with sort_by curriculum (default)" do
      let(:query_params) { base_params.merge(sort_by: "curriculum") }

      it "orders by curriculum" do
        expect(scope).to receive(:ordered).and_return(scope)
        subject
      end
    end

    context "with pagination" do
      it "paginates results" do
        expect(scope).to receive(:paginate).with(page: 3).and_return(scope)
        described_class.call(query_struct, page: 3)
      end
    end

    context "without pagination" do
      it "returns unpaginated results" do
        expect(scope).not_to receive(:paginate)
        subject
      end
    end
  end
end
