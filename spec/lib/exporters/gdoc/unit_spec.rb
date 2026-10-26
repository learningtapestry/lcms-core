# frozen_string_literal: true

require "rails_helper"

describe Exporters::Gdoc::Unit do
  let(:metadata) do
    {
      "subject" => "math", "grade" => "grade 2", "unit" => "unit 1",
      "unit_title" => "How do we explore and make choices about the world around us?",
      "unit_topic" => "Observing Our Natural World",
      "course" => "Kindergarten",
      "copyright" => "© San Mateo County Office of Education",
      "description" => "<p>This unit explores the interactions between humans and the environment.</p>",
      "license" => %(<p>Licensed under: <a href="https://creativecommons.org/licenses/by-nc-sa/4.0/">CC BY-NC-SA 4.0</a></p>),
      UnitPresenter::COVER_IMAGE_KEY => "https://bucket.s3.us-east-1.amazonaws.com/uploads/settings/cover.jpg",
      UnitPresenter::COVER_CREDIT_KEY => "iStock.com / Hakase_"
    }
  end
  let(:unit) { UnitPresenter.new(create(:resource, :unit, metadata:)) }
  let(:html) { described_class.new(unit, {}).send(:content) }

  before { allow(AssetHelper).to receive(:inline_data_uri).and_return(nil) }

  it "renders the cover page" do
    expect(html).to include("How do we explore and make choices about the world around us?")
    expect(html).to include("Observing Our Natural World")
    expect(html).to include("Kindergarten")
    expect(html).to include("Teacher Edition")
    expect(html).to include("iStock.com / Hakase_")
  end

  it "keeps the unit title a pure H1 so Google maps it to Heading 1" do
    expect(html).to match(%r{<h1><span class="o-gdoc-h1"[^>]*>How do we explore})
  end

  it "marks the cover image for full-width scaling by the Apps Script" do
    expect(html).to include(%(alt="[100]"))
  end

  it "right-aligns the topic, course and Teacher Edition lines" do
    %w(topic course edition).each do |part|
      expect(html).to match(/class="c-unit-cover__#{part}"[^>]*align="right"/)
    end
  end

  it "renders the copyright page after a page break" do
    break_at = html.index("--GDOC-PAGE-BREAK--")
    expect(break_at).to be > html.index("Teacher Edition")
    expect(html.index("© San Mateo County Office of Education")).to be > break_at
    expect(html).to match(/class="c-unit-copyright__statement"[^>]*align="center"/)
    expect(html).to include(%(href="https://creativecommons.org/licenses/by-nc-sa/4.0/"))
  end

  it "omits the copyright page when neither row is authored" do
    metadata.delete("copyright")
    metadata.delete("license")

    expect(html.scan("--GDOC-PAGE-BREAK--").size).to eq 1 # before the overview only
    expect(html).not_to include("c-unit-copyright")
  end

  describe "Unit Overview and Standards page" do
    before { allow(unit).to receive(:standard_codes).and_return(codes) }

    context "with lesson standards" do
      let(:codes) { %w(K.1) }

      it "follows the copyright page with the overview and the standards heading as Heading 2" do
        overview_at = html.index("Unit Overview")

        expect(overview_at).to be > html.index("c-unit-copyright")
        expect(html).to match(%r{<h2><span class="o-gdoc-h2"[^>]*>Unit Overview</span></h2>})
        expect(html).to match(%r{<h2><span class="o-gdoc-h2"[^>]*>Unit Standards</span></h2>})
        expect(html).to include("This unit explores the interactions between humans and the environment.")
      end
    end

    context "without lesson standards" do
      let(:codes) { [] }

      it "omits the Unit Standards heading" do
        expect(html).to include("Unit Overview")
        expect(html).not_to include("Unit Standards")
      end
    end
  end

  describe "Unit Materials pages" do
    let(:acknowledgements) do
      instance_double(MaterialPresenter, title: "Acknowledgements", name_date: false,
                                         content_for: "<h3>Steering Committee</h3><p>Dina Gilio-Whitaker</p>")
    end
    let(:worksheet) do
      instance_double(MaterialPresenter, title: "Class Roster", name_date: true, content_for: "<p>Roster body</p>")
    end

    before { allow(unit).to receive(:unit_materials).and_return([acknowledgements, worksheet]) }

    it "renders each material after a page break with a Heading 2 title and its Gdoc content" do
      ack_at = html.index("Acknowledgements")

      expect(ack_at).to be > html.index("c-unit-copyright")
      expect(html.index("Unit Overview")).to be > ack_at
      expect(html.index("Class Roster")).to be > html.index("Unit Overview")
      expect(html).to match(%r{<h2><span class="o-gdoc-h2"[^>]*>Acknowledgements</span></h2>})
      expect(html).to include("Steering Committee", "Roster body")
      expect(acknowledgements).to have_received(:content_for).with(:gdoc)
      expect(html.scan("--GDOC-PAGE-BREAK--").size).to eq 4 # copyright, acknowledgements, overview, roster
    end
  end

  describe "Section pages" do
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

    it "puts the divider and the overview each on their own page" do
      divider = html[html.index("c-bundle-divider__spacer")..]

      expect(html[...html.index("c-bundle-divider__spacer")]).to match(%r{>--GDOC-PAGE-BREAK--</p>\s*<p class="\z})
      expect(divider.index("Consumer Goods")).to be < divider.index("--GDOC-PAGE-BREAK--")
      expect(divider.index("--GDOC-PAGE-BREAK--")).to be < divider.index("Section Overview")
      expect(html).to match(/class="c-bundle-divider__title"[^>]*align="center"/)
      expect(html).to match(%r{<h2><span class="o-gdoc-h2"[^>]*>Section Learning Targets</span></h2>})
    end

    it "puts each section material on its own page after the overview page" do
      after_targets = html[html.index("Section Learning Targets")..]

      expect(after_targets.index("--GDOC-PAGE-BREAK--")).to be < after_targets.index("Life Cycle Cards")
      expect(html).to match(%r{<h2><span class="o-gdoc-h2"[^>]*>Life Cycle Cards</span></h2>})
    end

    it "opens each lesson with a Lesson Divider page after the section materials" do
      after_materials = html[html.index("Card set")..]

      expect(after_materials.index("--GDOC-PAGE-BREAK--")).to be < after_materials.index(">Lesson 1</p>")
      expect(after_materials).to include("How do we observe the world around us?", "Teacher Directions and Materials")
    end

    it "follows each Lesson Divider with the bundled Lesson Document" do
      lesson_html = html[html.index("Teacher Directions and Materials")..]

      expect(lesson_html.index("--GDOC-PAGE-BREAK--")).to be < lesson_html.index("Estimated Time: 2 Class Periods")
      expect(lesson_html).to match(%r{<h1><span class="o-gdoc-h1"[^>]*>Lesson 1: How do we observe the world around us\?</span></h1>})
      expect(lesson_html).to include("Lesson Content", "Activity body")
      expect(lesson).to have_received(:content_for).with(:gdoc)
    end

    it "follows the Lesson Document with its Lesson Materials, each on its own page" do
      worksheet = instance_double(MaterialPresenter, title: "Notice and Wonder", name_date: true, content_for: "<p>Worksheet body</p>")
      allow(lesson).to receive(:bundle_materials).and_return([worksheet])
      after_lesson = html[html.index("Activity body")..]

      expect(after_lesson.index("--GDOC-PAGE-BREAK--")).to be < after_lesson.index("Notice and Wonder")
      expect(after_lesson).to include("Worksheet body")
      expect(worksheet).to have_received(:content_for).with(:gdoc)
    end

    it "keeps the spacer sizes that position the divider" do
      expect(html).to match(/class="c-bundle-divider__spacer"[^>]*font-size: 36pt/)
    end
  end
end
