# frozen_string_literal: true

require "rails_helper"

describe UnitPresenter do
  let(:metadata) { { "subject" => "math", "grade" => "grade 2", "unit" => "unit 1" } }
  let(:unit) { create(:resource, :unit, metadata:) }
  let(:presenter) { described_class.new(unit) }

  describe "#base_filename" do
    it "is the unit's S3 folder name" do
      expect(presenter.base_filename).to eq presenter.s3_folder
    end

    it "accepts the keyword options other presenters take" do
      expect(presenter.base_filename(with_version: false)).to eq presenter.s3_folder
    end
  end

  describe "#pdf_filename" do
    it "appends .pdf to the base filename" do
      expect(presenter.pdf_filename).to eq "#{presenter.s3_folder}.pdf"
    end
  end

  describe "#cover_image_url" do
    context "without a cover image" do
      it { expect(presenter.cover_image_url).to be_nil }
    end

    context "with a cover image" do
      let(:url) { "https://bucket.s3.us-east-1.amazonaws.com/uploads/settings/cover.jpg" }
      let(:metadata) { super().merge(described_class::COVER_IMAGE_KEY => url) }

      it "inlines the image as a data URI" do
        allow(AssetHelper).to receive(:inline_data_uri).with(url, cache: anything).and_return("data:image/jpeg;base64,AAA")

        expect(presenter.cover_image_url).to eq "data:image/jpeg;base64,AAA"
      end

      it "falls back to the stored URL when inlining fails" do
        allow(AssetHelper).to receive(:inline_data_uri).and_return(nil)

        expect(presenter.cover_image_url).to eq url
      end
    end
  end

  describe "#cover_image_credit" do
    it "is nil when blank" do
      unit.metadata[described_class::COVER_CREDIT_KEY] = "  "

      expect(presenter.cover_image_credit).to be_nil
    end

    it "returns the stripped credit line" do
      unit.metadata[described_class::COVER_CREDIT_KEY] = " iStock.com / Hakase_ "

      expect(presenter.cover_image_credit).to eq "iStock.com / Hakase_"
    end
  end

  describe "bundled-document footer lines" do
    let(:metadata) do
      super().merge("copyright" => "© San Mateo County Office of Education", "version" => "August 2026",
                    "course" => "Kindergarten", "unit_title" => "How do we explore?")
    end

    it "joins copyright and version" do
      expect(presenter.footer_copyright).to eq "© San Mateo County Office of Education, August 2026"
    end

    it "joins course and unit title" do
      expect(presenter.footer_breadcrumb).to eq "Kindergarten • How do we explore?"
    end

    it "skips blank parts" do
      unit.metadata.delete("version")
      unit.metadata.delete("course")

      expect(presenter.footer_copyright).to eq "© San Mateo County Office of Education"
      expect(presenter.footer_breadcrumb).to eq "How do we explore?"
    end
  end

  describe "#copyright_page?" do
    it "is false without copyright or license" do
      expect(presenter.copyright_page?).to be false
    end

    it "is true with either row" do
      unit.metadata["license"] = "<p>CC BY-NC-SA</p>"

      expect(presenter.copyright_page?).to be true
    end
  end

  describe "Gdoc post-processing hooks" do
    let(:metadata) do
      super().merge("copyright" => "© X", "version" => "2026", "course" => "K", "unit_title" => "T")
    end

    it "fills the bundled-document template placeholders" do
      expect(presenter.gdoc_header).to eq [["{course}"], ["K"]]
      expect(presenter.gdoc_footer).to eq [["{bundle_copyright}", "{bundle_breadcrumb}"], ["© X, 2026", "K • T"]]
    end

    it "uses the bundle template" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GOOGLE_APPLICATION_TEMPLATE_BUNDLE").and_return("bundle_template")

      expect(presenter.gdoc_template_id).to eq "bundle_template"
    end

    it "names the missing setting when the bundle template is not set" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GOOGLE_APPLICATION_TEMPLATE_BUNDLE").and_return("")

      expect { presenter.gdoc_template_id }.to raise_error(KeyError, /GOOGLE_APPLICATION_TEMPLATE_BUNDLE is not set/)
    end

    it "keeps page 1 (the cover) free of the running header and footer" do
      expect(presenter.gdoc_distinct_first_page?).to be true
    end
  end

  describe "#standard_codes" do
    let(:lessons) do
      [
        double(standards: "K-ESS2-1, K.CC.4"),
        double(standards: "k-ess2-1; RL.K.1\nK.CC.4"),
        double(standards: nil),
        double(standards: " , SL.K.1 ")
      ]
    end

    before { allow(presenter).to receive(:lessons).and_return(lessons) }

    it "collects every lesson's codes in lesson order without duplicates" do
      expect(presenter.standard_codes).to eq %w(K-ESS2-1 K.CC.4 RL.K.1 SL.K.1)
    end
  end

  describe "#lessons" do
    # Documents attach to (and create) their resource hierarchy from metadata.
    def lesson(section, number, standards)
      create(:document, active: true, metadata: {
        "subject" => "math", "grade" => "3", "unit-id" => "u1",
        "section-number" => section.to_s, "lesson-number" => number.to_s, "standards" => standards
      })
    end

    it "returns the unit's lessons in curriculum order" do
      lesson(2, 1, "C")
      lesson(1, 2, "B")
      lesson(1, 1, "A")
      unit = Resource.units.sole

      expect(described_class.new(unit).lessons.map(&:standards)).to eq %w(A B C)
    end
  end

  describe "#unit_materials" do
    let!(:acknowledgements) { create(:material, identifier: "ack-1") }
    let!(:credits) { create(:material, identifier: "credits-1") }

    it "resolves the unit-materials row in authored order, case-insensitively, skipping unknowns" do
      unit.metadata["unit_materials"] = "CREDITS-1, missing-1; ack-1, credits-1"

      expect(presenter.unit_materials.map(&:id)).to eq [credits.id, acknowledgements.id]
      expect(presenter.unit_materials).to all(be_a(MaterialPresenter))
    end

    it "is empty without the row" do
      expect(presenter.unit_materials).to eq []
    end
  end

  describe "#acknowledgements_materials and #bundle_unit_materials" do
    it "splits the Acknowledgements out of the other unit materials" do
      ack = create(:material, identifier: "ack-1", metadata: { "material-title" => "ACKNOWLEDGMENTS" })
      roster = create(:material, identifier: "roster-1", metadata: { "material-title" => "Class Roster" })
      unit.metadata["unit_materials"] = "roster-1, ack-1"

      expect(presenter.acknowledgements_materials.map(&:id)).to eq [ack.id]
      expect(presenter.bundle_unit_materials.map(&:id)).to eq [roster.id]
    end
  end

  describe "#sections" do
    it "returns the unit's sections in curriculum order" do
      [2, 1].each do |section|
        create(:document, active: true, metadata: {
          "subject" => "math", "grade" => "3", "unit-id" => "u1", "section-number" => section.to_s, "lesson-number" => "1"
        })
      end

      sections = described_class.new(Resource.units.sole).sections

      expect(sections.map(&:section_number)).to eq %w(1 2)
      expect(sections).to all(be_a(SectionPresenter))
    end
  end

  describe "#overview_page?" do
    it "is true when the unit has a description" do
      unit.metadata["description"] = "<p>This unit explores...</p>"

      expect(presenter.overview_page?).to be true
    end

    it "is true when only standards are present" do
      allow(presenter).to receive(:standard_codes).and_return(["K.1"])

      expect(presenter.overview_page?).to be true
    end

    it "is false without either" do
      allow(presenter).to receive(:standard_codes).and_return([])

      expect(presenter.overview_page?).to be false
    end
  end

  describe "#unit_title" do
    it "prefers the unit-metadata title" do
      unit.metadata["unit_title"] = "How do we explore?"

      expect(presenter.unit_title).to eq "How do we explore?"
    end

    it "falls back to the resource title" do
      expect(presenter.unit_title).to eq unit.title
    end
  end
end
