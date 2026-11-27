# frozen_string_literal: true

require "rails_helper"

describe Exporters::Pdf::Unit do
  let(:metadata) do
    {
      "subject" => "math", "grade" => "grade 2", "unit" => "unit 1",
      "unit_title" => "How do we explore and make choices about the world around us?",
      "unit_topic" => "Observing Our Natural World",
      "course" => "Kindergarten",
      "copyright" => "© San Mateo County Office of Education",
      "version" => "August 2026",
      "license" => %(<p>Licensed under: <a href="https://creativecommons.org/licenses/by-nc-sa/4.0/">CC BY-NC-SA 4.0</a></p>),
      "description" => "<p>This unit explores the interactions between humans and the environment.</p>" \
                       "<p><strong>While investigating our natural world, students will</strong></p><ul><li>observe</li></ul>",
      UnitPresenter::COVER_IMAGE_KEY => "https://bucket.s3.us-east-1.amazonaws.com/uploads/settings/cover.jpg",
      UnitPresenter::COVER_CREDIT_KEY => "iStock.com / Hakase_"
    }
  end
  let(:unit) { UnitPresenter.new(create(:resource, :unit, metadata:)) }
  let(:calls) { [] }
  # Each pass returns a real PDF so the splice can be checked: the cover pass
  # yields one small page, the running-header pass `rest_pages` letter pages.
  let(:rest_pages) { 3 }
  let(:renderer) do
    recorded = calls
    rest = rest_pages
    Class.new do
      define_method(:call) do |html, options:|
        recorded << { html:, options: }
        pdf = CombinePDF.new
        if options.footer_html.nil? && html.include?("c-unit-cover__title") && !html.include?("c-unit-copyright")
          pdf << CombinePDF.create_page([0, 0, 100, 100])
        else
          rest.times { pdf << CombinePDF.create_page }
        end
        pdf.to_pdf
      end
    end.new
  end

  before do
    allow(AssetHelper).to receive(:inline_data_uri).and_return(nil)
    allow(Exporters::Pdf::RendererRegistry).to receive(:fetch_for).and_return(renderer)
  end

  describe "#export" do
    subject(:pdf) { CombinePDF.parse(described_class.new(unit, {}).export) }

    it "splices the cover onto pages 2..N of the running-header pass" do
      expect(pdf.pages.size).to eq rest_pages
      expect(pdf.pages.first[:MediaBox]).to eq [0, 0, 100, 100]
    end

    context "with a renderer that does not render the HTML (gdoc_pdf)" do
      before do
        html_free = Class.new(Exporters::Pdf::Renderers::Base) { def self.renders_html? = false }
        allow(Exporters::Pdf::RendererRegistry).to receive(:fetch).and_return(html_free)
      end

      it "renders once, without splicing" do
        pdf

        expect(calls.size).to eq 1
        expect(pdf.pages.size).to eq rest_pages
      end
    end

    it "renders the cover alone, without running header/footer or the bundle margins" do
      pdf
      cover = calls.first

      expect(cover[:html]).to include("Teacher Edition", "iStock.com / Hakase_", metadata[UnitPresenter::COVER_IMAGE_KEY])
      expect(cover[:html]).not_to include("c-unit-copyright")
      expect(cover[:options].header_html).to be_nil
      expect(cover[:options].footer_html).to be_nil
      expect(cover[:options].margin).not_to eq described_class::BUNDLE_MARGIN
    end

    it "renders the remaining pages behind a placeholder page with the bundled header and footer" do
      pdf
      rest = calls.last

      expect(rest[:html]).to include("c-unit-cover-placeholder")
      expect(rest[:html]).not_to include("c-unit-cover__title")
      expect(rest[:html]).to include("© San Mateo County Office of Education", "Licensed under:")
      expect(rest[:html]).to include(%(href="https://creativecommons.org/licenses/by-nc-sa/4.0/"))
      expect(rest[:options].margin).to eq described_class::BUNDLE_MARGIN
      expect(rest[:options].header_html).to include("c-bundle-header", "Kindergarten")
      expect(rest[:options].footer_html).to include(
        "© San Mateo County Office of Education, August 2026",
        "Kindergarten • How do we explore and make choices about the world around us?",
        %(class="pageNumber")
      )
    end

    it "renders the Unit Overview with the description's formatting after the copyright page" do
      allow(unit).to receive(:standard_codes).and_return([])
      pdf
      html = calls.last[:html]

      expect(html.index("Unit Overview")).to be > html.index("c-unit-copyright")
      expect(html).to include("<strong>While investigating our natural world, students will</strong>", "<li>observe</li>")
      expect(html).not_to include("Unit Standards")
    end

    it "adds the Unit Standards heading when the unit's lessons have standards" do
      allow(unit).to receive(:standard_codes).and_return(%w(K.1))
      pdf

      expect(calls.last[:html]).to include("Unit Standards")
    end

    it "escapes the authored copyright statement" do
      metadata["copyright"] = "<script>alert(1)</script>"
      pdf

      expect(calls.last[:html]).not_to include("<script>alert(1)</script>")
      expect(calls.last[:options].footer_html).not_to include("<script>alert(1)</script>")
    end

    context "with unit materials" do
      let(:acknowledgements) do
        instance_double(MaterialPresenter, title: "Acknowledgements", name_date: false,
                                           content_for: "<h3>Steering Committee</h3><p>Dina Gilio-Whitaker</p>")
      end
      let(:worksheet) do
        instance_double(MaterialPresenter, title: "Class Roster", name_date: true, content_for: "<p>Roster body</p>")
      end

      before { allow(unit).to receive(:unit_materials).and_return([acknowledgements, worksheet]) }

      it "renders the Acknowledgements after the copyright page and the other materials after the overview" do
        pdf
        html = calls.last[:html]
        ack_at = html.index("Acknowledgements")

        expect(ack_at).to be > html.index("c-unit-copyright")
        expect(html.index("Unit Overview")).to be > ack_at
        expect(html.index("Class Roster")).to be > html.index("Unit Overview")
        expect(html).to include(%(<h2 class="c-unit-material__title">Acknowledgements</h2>), "<h3>Steering Committee</h3>")
        expect(acknowledgements).to have_received(:content_for).with(:default)
      end

      it "adds the Name/Date table only for materials that ask for it" do
        pdf
        html = calls.last[:html]

        expect(html.scan(%(<table class="c-unit-material__namedate)).size).to eq 1
        expect(html.index("c-unit-material__namedate")).to be > html.index("Acknowledgements")
      end
    end

    context "with sections" do
      let(:section) do
        instance_double(SectionPresenter, section_title: "Consumer Goods", section_number: "1", lessons_label: "Lessons 1-2",
                                          overview_html: overview, learning_targets: targets,
                                        section_materials: [section_material], lessons: [lesson])
      end
      let(:overview) { "<p>Students investigate consumer goods.</p>" }
      let(:targets) { ["gather <strong>information</strong>", "develop models"] }
    let(:lesson) do
      DocumentPresenter.new(create(:document, metadata: {
        "subject" => "math", "grade" => "3", "unit-id" => "u1", "section-number" => "1", "lesson-number" => "1",
        "lesson_number" => 1, "lesson_title" => "How do we observe the world around us?",
        "standards" => "Sci6.1.2, RL.6.1a", "description" => "<p>In this lesson, students observe.</p>",
        "description_future" => "<p style=\"height:11pt\"></p>"
      }, activity_metadata: [{ "activity-time" => "60", "vocabulary" => "observe, wonder" }])).tap { allow(it).to receive(:content_for).and_return("<p>Activity body</p>") }
    end
    let(:section_material) do
      instance_double(MaterialPresenter, title: "Life Cycle Cards", name_date: true, content_for: "<p>Card set</p>")
    end

      before { allow(unit).to receive(:sections).and_return([section]) }

      it "renders the divider and then the overview page after the unit front matter" do
        pdf
        html = calls.last[:html]
        divider_at = html.index("c-bundle-divider")

        expect(divider_at).to be > html.index("Unit Overview")
        expect(html).to include(">Consumer Goods</p>", ">Section 1</p>")
        expect(html).to match(/c-bundle-divider__note">\s*Lessons 1-2/)
        expect(html.index("Section Overview")).to be > divider_at
        expect(html).to include("Section Learning Targets", "In this section, students will:",
                                "<li>gather <strong>information</strong></li>")
      end

      it "follows the overview page with the section materials" do
        pdf
        html = calls.last[:html]

        expect(html.index("Life Cycle Cards")).to be > html.index("Section Learning Targets")
        expect(html).to include(%(<h2 class="c-unit-material__title">Life Cycle Cards</h2>), "Card set")
      end

      it "opens each lesson with a Lesson Divider after the section materials" do
        pdf
        html = calls.last[:html]
        lesson_at = html.index(">Lesson 1</p>")

        expect(lesson_at).to be > html.index("Life Cycle Cards")
        expect(html[lesson_at..]).to include("How do we observe the world around us?", "Teacher Directions and Materials")
      end

      it "follows the Lesson Document with its Lesson Materials, each on its own page" do
        worksheet = instance_double(MaterialPresenter, title: "Notice and Wonder", name_date: true, content_for: "<p>Worksheet body</p>")
        allow(lesson).to receive(:bundle_materials).and_return([worksheet])
        pdf
        after_lesson = calls.last[:html][calls.last[:html].index("Activity body")..]

        expect(after_lesson).to match(%r{u-pdf-alwaysbreak.*Notice and Wonder.*Worksheet body}m)
        expect(worksheet).to have_received(:content_for).with(:default)
      end

      it "follows each Lesson Divider with the bundled Lesson Document" do
        pdf
        html = calls.last[:html]
        lesson_html = html[html.index(%(class="c-bundle-lesson"))..]

        expect(lesson_html).to include("Estimated Time: 2 Class Periods", "Lesson 1: How do we observe the world around us?",
                                       "<strong>Standards:</strong> Sci6.1.2, RL.6.1a", "observe, wonder",
                                       "Lesson Content", "Activity body")
        expect(lesson_html).not_to include("c-lesson-banner__strip") # the bundle header replaces it
        expect(lesson).to have_received(:content_for).with(:default)
      end

      context "without overview or learning targets" do
        let(:overview) { nil }
        let(:targets) { [] }

        it "renders only the divider" do
          pdf

          expect(calls.last[:html]).to include("c-bundle-divider")
          expect(calls.last[:html]).not_to include("c-section-overview")
        end
      end
    end

    context "without copyright or license" do
      let(:rest_pages) { 1 }

      before do
        metadata.delete("copyright")
        metadata.delete("license")
        metadata.delete("description")
      end

      it "produces the cover page only" do
        expect(pdf.pages.size).to eq 1
        expect(calls.last[:html]).not_to include("c-unit-copyright")
      end
    end

    context "when tagged / PDF-UA output is requested" do
      subject(:export) { described_class.new(unit, accessibility: :pdf_ua).export }

      it "renders once, without splicing, so the structure tree survives" do
        export

        expect(calls.size).to eq 1
        expect(calls.first[:html]).to include("c-unit-cover__title", "c-unit-copyright")
      end
    end
  end
end
