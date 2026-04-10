# frozen_string_literal: true

require "rails_helper"

describe CurriculumForm do
  describe "#save" do
    context "when change_log is empty" do
      it "returns true" do
        form = described_class.new
        expect(form.save).to be true
      end
    end

    context "when handling create operation" do
      let!(:parent) { build_or_return_resources_chain(%w(math 2 1)) }

      it "creates a new child resource" do
        change_log = [{ "op" => "create", "name" => "2", "parent" => parent.id,
                        "curriculum" => %w(math 2 1) }].to_json

        form = described_class.new(change_log:)

        expect { form.save }.to change(Resource, :count)
      end

      it "skips create when name is blank" do
        change_log = [{ "op" => "create", "name" => "", "parent" => parent.id,
                        "curriculum" => %w(math 2 1) }].to_json

        form = described_class.new(change_log:)

        expect { form.save }.not_to change(Resource, :count)
      end
    end

    context "when handling remove operation" do
      let!(:resource) { build_or_return_resources_chain(%w(math 2 1 1 1)) }

      it "detaches resource from curriculum" do
        change_log = [{ "op" => "remove", "id" => resource.id,
                        "curriculum" => %w(math 2 1 1 1) }].to_json

        form = described_class.new(change_log:)
        form.save

        resource.reload
        expect(resource.parent_id).to be_nil
        expect(resource.curriculum_id).to be_nil
      end
    end

    context "when handling rename operation" do
      let!(:resource) { build_or_return_resources_chain(%w(math 2 1 1 1)) }

      it "updates the short_title" do
        change_log = [{ "op" => "rename", "id" => resource.id,
                        "from" => "1", "to" => "Renamed Lesson",
                        "curriculum" => %w(math 2 1 1) }].to_json

        form = described_class.new(change_log:)
        form.save

        expect(resource.reload.short_title).to eq "Renamed Lesson"
      end
    end
  end
end
