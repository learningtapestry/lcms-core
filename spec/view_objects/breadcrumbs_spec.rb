# frozen_string_literal: true

require "rails_helper"

describe Breadcrumbs do
  let(:breadcrumbs) { described_class.new(resource) }
  let(:metadata) { Resource.metadata_from_dir(dir) }
  let(:resource) { create :resource, curriculum_type: type, metadata: }

  context "grade" do
    let(:type) { "grade" }

    context "math pk" do
      let(:dir) { %w(math prekindergarten) }

      it { expect(breadcrumbs.title).to eq "Mathematics / prekindergarten" }
      it { expect(breadcrumbs.short_title).to eq "MATH / PK" }
    end
  end

  context "unit" do
    let(:type) { "unit" }

    context "math pk u5" do
      let(:dir) { ["math", "prekindergarten", "unit 5"] }

      it { expect(breadcrumbs.title).to eq "Mathematics / PK / unit 5" }
    end
  end

  context "section" do
    let(:type) { "section" }

    context "math pk u5 s1" do
      let(:dir) { ["math", "prekindergarten", "unit 5", "section 1"] }

      it { expect(breadcrumbs.title).to eq "Mathematics / PK / U5 / section 1" }
      it { expect(breadcrumbs.short_title).to eq "MATH / PK / U5 / S1" }
    end
  end

  context "lesson" do
    let(:type) { "lesson" }

    context "math pk u5 s2 l3" do
      let(:dir) { ["math", "prekindergarten", "unit 5", "section 2", "lesson 3"] }

      it { expect(breadcrumbs.title).to eq "Mathematics / PK / U5 / S2 / lesson 3" }
      it { expect(breadcrumbs.short_title).to eq "MATH / PK / U5 / S2 / L3" }
    end
  end
end
