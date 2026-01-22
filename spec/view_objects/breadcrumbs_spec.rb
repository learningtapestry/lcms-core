# frozen_string_literal: true

require "rails_helper"

describe Breadcrumbs do
  let(:breadcrumbs) { described_class.new(resource) }
  let(:metadata) { Resource.metadata_from_dir(dir) }
  let(:resource) { create :resource, curriculum_type: type, metadata: }

  context "grade" do
    let(:type) { "grade" }

    context "ela g2" do
      let(:dir) { ["ela", "grade 2"] }

      it { expect(breadcrumbs.title).to eq "English Language Arts / grade 2" }
      xit { expect(breadcrumbs.short_title).to eq "ELA / G2" }
    end
    context "math pk" do
      let(:dir) { %w(math prekindergarten) }

      it { expect(breadcrumbs.title).to eq "Mathematics / prekindergarten" }
      it { expect(breadcrumbs.short_title).to eq "MATH / PK" }
    end
    context "ela k" do
      let(:dir) { %w(ela kindergarten) }

      it { expect(breadcrumbs.title).to eq "English Language Arts / kindergarten" }
      it { expect(breadcrumbs.short_title).to eq "ELA / K" }
    end
  end

  context "module" do
    let(:type) { "module" }

    context "ela g2 m1" do
      let(:dir) { ["ela", "grade 2", "module 1"] }

      it { expect(breadcrumbs.title).to eq "English Language Arts / G2 / module 1" }
    end
    context "math pk m5" do
      let(:dir) { ["math", "prekindergarten", "module 5"] }

      it { expect(breadcrumbs.title).to eq "Mathematics / PK / module 5" }
    end
  end

  context "unit/topic" do
    let(:type) { "unit" }

    context "ela g2 m1 u11" do
      let(:dir) { ["ela", "grade 2", "module 1", "unit 11"] }

      it { expect(breadcrumbs.title).to eq "English Language Arts / G2 / M1 / unit 11" }
      it { expect(breadcrumbs.short_title).to eq "ELA / G2 / M1 / U11" }
    end
    context "math pk m5 u1" do
      let(:dir) { ["math", "prekindergarten", "module 5", "unit 1"] }

      it { expect(breadcrumbs.title).to eq "Mathematics / PK / M5 / unit 1" }
      it { expect(breadcrumbs.short_title).to eq "MATH / PK / M5 / U1" }
    end
  end

  context "lesson/part" do
    let(:type) { "lesson" }

    context "ela g2 m1 u1 l9" do
      let(:dir) { ["ela", "grade 2", "module 1", "unit 1", "lesson 9"] }

      it { expect(breadcrumbs.title).to eq "English Language Arts / G2 / M1 / U1 / lesson 9" }
      it { expect(breadcrumbs.short_title).to eq "ELA / G2 / M1 / U1 / L9" }
    end
    context "math pk m5 u2 l3" do
      let(:dir) { ["math", "prekindergarten", "module 5", "unit 2", "lesson 3"] }

      it { expect(breadcrumbs.title).to eq "Mathematics / PK / M5 / U2 / lesson 3" }
      it { expect(breadcrumbs.short_title).to eq "MATH / PK / M5 / U2 / L3" }
    end
  end
end
