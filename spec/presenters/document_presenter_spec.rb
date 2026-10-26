# frozen_string_literal: true

require "rails_helper"

describe DocumentPresenter do
  let(:document) do
    create(:document, metadata: {
      "lesson_title" => "Introduction to Fractions",
      "grade" => "3",
      "unit_id" => "1",
      "section_number" => "1",
      "lesson_number" => "5",
      "subject" => "math"
    })
  end
  let(:presenter) { described_class.new(document) }

  describe "#bundle_materials" do
    def material(identifier, type, order = nil)
      create(:material, identifier:, metadata: { "material-title" => identifier, "material-type" => type,
                                                 "material-order" => order }.compact)
    end

    before do
      material("ws-a1", "worksheet")
      material("ws-a2-02", "worksheet", 2)
      material("ws-a2-01", "worksheet", 1)
      material("resp-a1", "response")
      material("resp-a2-02", "response", 2)
      material("resp-a2-01", "response", 1)
      material("ref-a2", "reference")
      material("ref-a3", "reference")
      material("slides-a1", "slides")
      document.update!(activity_metadata: [
        { "idx" => 1, "activity-materials-student" => "[material: ws-a1], [material: resp-a1]",
          "activity-materials-teacher" => "[material: slides-a1]" },
        { "idx" => 2, "activity-materials-student" => "[material: ws-a2-02]; [material: ws-a2-01]",
          "activity-materials-group" => "resp-a2-02, resp-a2-01",
          "activity-materials-class" => "[material: ref-a2], [material: ws-a1]" },
        { "idx" => 3, "activity-materials-class" => "[material: ref-a3], [material: missing]" }
      ])
    end

    it "lists worksheets, responses and references by activity, then material-order (the spec's example)" do
      expect(presenter.bundle_materials.map(&:identifier)).to eq %w(
        ws-a1 ws-a2-01 ws-a2-02 resp-a1 resp-a2-01 resp-a2-02 ref-a2 ref-a3
      )
      expect(presenter.bundle_materials).to all(be_a(MaterialPresenter))
    end

    it "lists every material for the lesson folder, of any type, in activity order" do
      expect(presenter.lesson_materials.map(&:identifier)).to eq %w(
        ws-a1 resp-a1 slides-a1 ws-a2-02 ws-a2-01 resp-a2-02 resp-a2-01 ref-a2 ref-a3
      )
    end

    it "includes materials recorded by id at import" do
      extra = material("ws-a3", "worksheet")
      document.activity_metadata.last["material_ids"] = [extra.id]

      expect(presenter.bundle_materials.map(&:identifier)).to include("ws-a3")
    end
  end

  describe "#gdoc_header" do
    it "returns parallel [patterns, values] arrays for title, unit title, lesson type, and estimated time" do
      patterns, values = presenter.gdoc_header

      expect(patterns).to eq(["{title}", "{unit_title}", "{lesson_type}", "{estimated_time}"])
      expect(values).to eq([
        presenter.lesson_title,
        presenter.unit_title,
        presenter.lesson_type_label,
        presenter.estimated_time
      ])
    end

    context "when lesson_title is present" do
      it "puts the title first in the values array, aligned with {title}" do
        patterns, values = presenter.gdoc_header

        expect(patterns.first).to eq("{title}")
        expect(values.first).to eq("Introduction to Fractions")
      end
    end

    context "when lesson_title is blank" do
      let(:document) do
        create(:document, metadata: {
          "lesson_title" => "",
          "grade" => "3",
          "unit_id" => "1",
          "section_number" => "1",
          "lesson_number" => "5",
          "subject" => "math"
        })
      end

      it "returns an empty title value" do
        _patterns, values = presenter.gdoc_header

        expect(values.first).to eq("")
      end
    end
  end

  describe "#sample_responses_folder_name" do
    it "joins the unit id, grade and two-digit lesson number" do
      document.update!(metadata: document.metadata.merge("unit_id" => "s2s", "grade" => "K", "lesson_number" => "1"))

      expect(described_class.new(document).sample_responses_folder_name).to eq "S2S_GK_01_Sample_Student_Responses"
    end

    it "keeps a longer lesson number and drops a blank unit id" do
      document.update!(metadata: document.metadata.merge("unit_id" => "", "lesson_number" => "12"))

      expect(described_class.new(document).sample_responses_folder_name).to eq "G3_12_Sample_Student_Responses"
    end
  end

  describe "#short_breadcrumb" do
    it "labels a numbered grade G<n>" do
      expect(presenter.short_breadcrumb).to eq "Mathematics / G3 / U1 / S1 / Lesson 5"
    end

    it "keeps Kindergarten as K rather than 0" do
      document.update!(metadata: document.metadata.merge("grade" => "k"))

      expect(described_class.new(document).short_breadcrumb).to eq "Mathematics / K / U1 / S1 / Lesson 5"
    end

    it "leaves out a blank grade" do
      document.update!(metadata: document.metadata.merge("grade" => ""))

      expect(described_class.new(document).short_breadcrumb).to eq "Mathematics / U1 / S1 / Lesson 5"
    end
  end

  describe "#lesson_type_label" do
    let(:document) do
      create(:document, metadata: {
        "lesson_title" => "Introduction to Fractions",
        "grade" => "3",
        "unit_id" => "1",
        "section_number" => "1",
        "lesson_number" => "5",
        "subject" => "math",
        "lesson_type" => lesson_type
      })
    end

    context "when the abbreviation is mapped in Settings" do
      let(:lesson_type) { "AP" }

      before { Settings.set(:documents, "lesson_types" => { "AP" => "Anchoring Phenomenon" }) }

      it "returns the configured label" do
        expect(presenter.lesson_type_label).to eq("Anchoring Phenomenon")
      end
    end

    context "when the abbreviation matches case-insensitively" do
      let(:lesson_type) { "ap" }

      before { Settings.set(:documents, "lesson_types" => { "AP" => "Anchoring Phenomenon" }) }

      it "returns the configured label" do
        expect(presenter.lesson_type_label).to eq("Anchoring Phenomenon")
      end
    end

    context "when the abbreviation is not in the map" do
      let(:lesson_type) { "unmapped_type" }

      before { Settings.set(:documents, "lesson_types" => { "AP" => "Anchoring Phenomenon" }) }

      it "falls back to titleizing the raw value" do
        expect(presenter.lesson_type_label).to eq("Unmapped Type")
      end
    end

    context "when lesson_type is blank" do
      let(:lesson_type) { "" }

      it "returns an empty string" do
        expect(presenter.lesson_type_label).to eq("")
      end
    end
  end

  describe "#banner_title" do
    it "prefixes the lesson title with the lesson number" do
      expect(presenter.banner_title).to eq("Lesson 5: Introduction to Fractions")
    end

    context "without a lesson number" do
      let(:document) do
        create(:document, metadata: {
          "lesson_title" => "Introduction to Fractions",
          "grade" => "3",
          "unit_id" => "1",
          "section_number" => "1",
          "subject" => "math"
        })
      end

      it "returns the bare title" do
        expect(presenter.banner_title).to eq("Introduction to Fractions")
      end
    end

    context "without a lesson title" do
      let(:document) do
        create(:document, metadata: {
          "lesson_title" => "",
          "grade" => "3",
          "unit_id" => "1",
          "section_number" => "1",
          "lesson_number" => "5",
          "subject" => "math"
        })
      end

      it "returns the lesson label with no dangling colon" do
        expect(presenter.banner_title).to eq("Lesson 5")
      end
    end
  end

  describe "#unit_title" do
    context "without a unit resource ancestor" do
      it "falls back to the upcased unit_id" do
        expect(presenter.unit_title).to eq("Unit 1")
      end
    end

    context "with a unit resource carrying unit_title metadata" do
      let(:unit) { create(:resource, :unit, metadata: { "unit_title" => "Expressions and Equations" }) }

      before { document.resource.update!(parent: unit) }

      it "prefers the authored unit-metadata title" do
        expect(presenter.unit_title).to eq("Expressions and Equations")
      end
    end
  end

  describe "integration with Google::ScriptService" do
    it "provides compatible format for ScriptService#parameters" do
      header = presenter.gdoc_header

      expect(header).to be_an(Array)
      expect(header.all? { |row| row.is_a?(Array) }).to be true
    end
  end

  describe "#gdoc_footer" do
    it "returns parallel [patterns, values] arrays mirroring the R2 PDF footer" do
      patterns, values = presenter.gdoc_footer

      expect(patterns).to eq(["{copyright}", "{attribution}", "{course}", "{unit_lesson}"])
      expect(values).to eq([
        presenter.footer_copyright,
        presenter.footer_attribution,
        nil,
        presenter.footer_course_lesson
      ])
    end

    # The template's own {course} paragraph is retired: it must still be
    # substituted (blank) rather than left as literal text in the exported doc.
    it "blanks the legacy {course} slot instead of dropping the placeholder" do
      patterns, values = presenter.gdoc_footer

      expect(patterns).to include("{course}")
      expect(values[patterns.index("{course}")]).to be_nil
    end

    context "with an authored cc-attribution" do
      let(:document) do
        create(:document, metadata: {
          "lesson_title" => "Introduction to Fractions",
          "grade" => "3",
          "unit_id" => "1",
          "section_number" => "1",
          "lesson_number" => "5",
          "subject" => "math",
          "cc-attribution" => "Adapted from OpenSciEd, CC BY-NC-SA 4.0"
        })
      end

      it "carries the per-lesson attribution into the {attribution} slot" do
        patterns, values = presenter.gdoc_footer

        expect(values[patterns.index("{attribution}")]).to eq("Adapted from OpenSciEd, CC BY-NC-SA 4.0")
      end
    end

    it "leaves the attribution slot blank when the lesson authors none" do
      patterns, values = presenter.gdoc_footer

      expect(values[patterns.index("{attribution}")]).to be_nil
    end

    context "with copyright_text Setting" do
      before { Settings.set(:documents, "copyright_text" => "© Acme, Spring 2026") }

      it "carries the configured copyright into the {copyright} slot" do
        patterns, values = presenter.gdoc_footer

        expect(patterns.first).to eq("{copyright}")
        expect(values.first).to include("© Acme, Spring 2026")
      end
    end
  end

  describe "#footer_course_lesson" do
    # No unit-metadata here, so there is no course — the breadcrumb must NOT
    # invent one from the resource label the lesson importer generated.
    it "degrades to the bare lesson label when the unit has no metadata" do
      expect(presenter.footer_course_lesson).to eq("Lesson 5")
    end

    context "when unit and lesson are missing" do
      let(:document) { Document.new(metadata: { "subject" => "math" }) }

      it "returns nil" do
        expect(presenter.footer_course_lesson).to be_nil
      end
    end

    context "with every lesson of the unit imported" do
      before { create(:curriculum) }

      def create_lesson(num)
        create(:document, metadata: {
          "subject" => "science", "grade" => "10", "unit-id" => "GG",
          "section-number" => "1", "lesson-number" => num.to_s, "lesson-title" => "L#{num}"
        })
      end

      let!(:lessons) { (1..3).map { |n| create_lesson(n) } }

      before do
        unit = lessons.first.resource.ancestors.find(&:unit?)
        unit.update_columns(metadata: unit.metadata.merge("course" => "Biology"))
      end

      it "counts the unit's lessons into the breadcrumb" do
        expect(described_class.new(lessons.second).footer_course_lesson)
          .to eq("Biology • Lesson 2 of 3")
      end

      it "counts lessons across sections, not just this lesson's own section" do
        create(:document, metadata: {
          "subject" => "science", "grade" => "10", "unit-id" => "GG",
          "section-number" => "2", "lesson-number" => "1", "lesson-title" => "S2 L1"
        })

        expect(described_class.new(lessons.first).footer_course_lesson)
          .to eq("Biology • Lesson 1 of 4")
      end
    end

    # A lesson doc with a blank section-number lands on a section-typed
    # resource, so its unit holds no lesson resources — better a short label
    # than "Lesson 7 of 0".
    context "when the unit holds fewer lessons than this lesson's number" do
      before { create(:curriculum) }

      let(:document) do
        create(:document, metadata: {
          "subject" => "science", "grade" => "10", "unit-id" => "GG",
          "section-number" => "", "lesson-number" => "7", "lesson-title" => "L7"
        })
      end

      it "omits the total" do
        expect(presenter.footer_course_lesson).to eq("Lesson 7")
      end
    end
  end

  describe "footer lines from unit-metadata" do
    before { create(:curriculum) }

    let(:document) do
      create(:document, metadata: {
        "subject" => "math",
        "grade" => "6",
        "unit-id" => "2",
        "section-number" => "1",
        "lesson-number" => "3",
        "lesson-title" => "L3"
      })
    end

    before do
      # The unit Resource carries unit-metadata (populated by UnitBuildService).
      unit = document.resource.ancestors.find(&:unit?)
      unit.update_columns(metadata: unit.metadata.merge(
        "course" => "Biology", "version" => "v1.0", "unit-title" => "Cells"
      ))
    end

    it "#footer_course reads the course from unit-metadata" do
      expect(described_class.new(document).footer_course).to eq("Biology")
    end

    it "#footer_course_lesson leads with the course, not the unit title" do
      expect(described_class.new(document).footer_course_lesson).to eq("Biology • Lesson 3")
    end

    it "#footer_copyright appends the unit version to the boilerplate copyright" do
      Settings.set(:documents, "copyright_text" => "© Acme")

      expect(described_class.new(document).footer_copyright).to eq("© Acme, v1.0")
    end
  end

  describe "#materials_summary" do
    context "when document has no activity metadata" do
      it "renders every category as \"None\"" do
        expect(presenter.materials_summary).to eq(
          "Individual Student Materials" => "None",
          "Pair Materials" => "None",
          "Small Group Materials" => "None",
          "Class Materials" => "None",
          "Teacher Materials" => "None"
        )
      end
    end

    context "when document has activity metadata" do
      let(:document) do
        create(:document,
               metadata: {
                 "lesson_title" => "Sample",
                 "grade" => "6",
                 "subject" => "science"
               },
               activity_metadata: [
                 { "activity-materials-student" => "Notebook, [material: worksheet01]",
                   "activity-materials-class" => "Lesson 7 Slides" },
                 { "activity-materials-student" => "[material: worksheet02]",
                   "activity-materials-pair" => "Calculator" }
               ])
      end

      it "aggregates and dedupes materials across activities" do
        summary = presenter.materials_summary

        expect(summary["Individual Student Materials"]).to eq(
          %(<ul class="c-lesson-materials__list"><li>Notebook</li>) +
          %(<li><span class="badge text-bg-danger">Unknown material: worksheet01</span></li>) +
          %(<li><span class="badge text-bg-danger">Unknown material: worksheet02</span></li></ul>)
        )
        expect(summary["Pair Materials"]).to eq(%(<ul class="c-lesson-materials__list"><li>Calculator</li></ul>))
        expect(summary["Class Materials"]).to eq(%(<ul class="c-lesson-materials__list"><li>Lesson 7 Slides</li></ul>))
      end

      it "resolves [material: id] tokens to plain identifier text matching MaterialTag when the material exists" do
        create(:material, identifier: "worksheet01")

        summary = presenter.materials_summary

        expect(summary["Individual Student Materials"])
          .to include(%(<span class="o-ld-material">worksheet01</span>))
        expect(summary["Individual Student Materials"])
          .not_to include("[material:")
      end

      it "flags unknown material tokens with the same badge as the lesson body" do
        summary = presenter.materials_summary

        expect(summary["Individual Student Materials"])
          .to include(%(<span class="badge text-bg-danger">Unknown material: worksheet01</span>))
        expect(summary["Individual Student Materials"]).not_to include("[material:")
      end

      it "renders empty rows as 'None'" do
        summary = presenter.materials_summary

        expect(summary["Small Group Materials"]).to eq("None")
        expect(summary["Teacher Materials"]).to eq("None")
      end

      it "always includes all five canonical rows" do
        expect(presenter.materials_summary.keys).to eq([
          "Individual Student Materials",
          "Pair Materials",
          "Small Group Materials",
          "Class Materials",
          "Teacher Materials"
        ])
      end
    end

    context "when a document was parsed before the teacher-materials rename" do
      let(:document) do
        create(:document,
               metadata: { "subject" => "science", "grade" => "6" },
               activity_metadata: [{ "activity-metadata-teacher" => "Answer key" }])
      end

      it "still reads teacher materials from the legacy key" do
        expect(presenter.materials_summary["Teacher Materials"]).to eq(%(<ul class="c-lesson-materials__list"><li>Answer key</li></ul>))
      end
    end

    # The spec's sample rows (LCMS Core Lesson > Materials Table), as Google Docs
    # HTML captured by Tables::Activity under "<key>-html".
    context "when activities carry the authored cell HTML" do
      let(:italic) { %(<span style="font-style:italic">) }
      let(:document) do
        create(:document,
               metadata: { "subject" => "science", "grade" => "K" },
               activity_metadata: [
                 { "activity-materials-student" => "School Map (if available), [material: ws01]",
                   "activity-materials-student-html" =>
                     "<p>#{italic}School Map</span><span> (if available), [material: ws01]</span></p>",
                   "activity-materials-class-html" => "<p><span>Chart paper</span></p>" },
                 { "activity-materials-student-html" => "<p><span>[material: ws01]</span></p>",
                   "activity-materials-class-html" =>
                     %(<p>#{italic}Wonder Walkers</span><span> by Micha Archer, [material: ws01]</span></p>),
                   "activity-materials-teacher-html" =>
                     %(<p><span>class model of the </span><span style="font-style:italic;font-weight:700">School Map</span></p>) }
               ])
      end

      before { create(:material, identifier: "ws01", metadata: { "material_title" => "Worksheet 01: Initial Explanatory Model" }) }

      it "lists one bullet per entry, keeping authored formatting and resolving material titles" do
        summary = presenter.materials_summary

        expect(summary["Individual Student Materials"]).to eq(
          %(<ul class="c-lesson-materials__list"><li>#{italic}School Map</span><span> (if available)</span></li>) +
          %(<li><span><span class="o-ld-material">Worksheet 01: Initial Explanatory Model</span></span></li></ul>)
        )
        expect(summary["Class Materials"]).to include(
          "<li><span>Chart paper</span></li>",
          "<li>#{italic}Wonder Walkers</span><span> by Micha Archer</span></li>"
        )
        expect(summary["Teacher Materials"]).to include(%(<span style="font-style:italic;font-weight:700">School Map</span>))
      end

      it "drops a repeated entry within a row" do
        expect(presenter.materials_summary["Class Materials"].scan("Worksheet 01").size).to eq 1
      end
    end

    context "when authored text contains markup-significant characters" do
      let(:document) do
        create(:document,
               metadata: { "subject" => "science", "grade" => "6" },
               activity_metadata: [{ "activity-materials-class" => "Beakers <250ml> & tongs" }])
      end

      # Both header views emit these values with `raw`, so anything the author
      # types must be escaped here or the browser eats it as a tag.
      it "escapes it instead of letting it be parsed as markup" do
        expect(presenter.materials_summary["Class Materials"]).to include("<li>Beakers &lt;250ml&gt; &amp; tongs</li>")
      end
    end
  end

  describe "#vocabulary" do
    context "when activities define vocabulary" do
      let(:document) do
        create(:document,
               metadata: { "subject" => "math", "grade" => "6" },
               activity_metadata: [
                 { "vocabulary" => "energy, force" },
                 { "vocabulary" => "force, motion" },
                 { "vocabulary" => "" }
               ])
      end

      it "compiles and dedupes vocabulary across activities" do
        expect(presenter.vocabulary).to eq("energy, force, motion")
      end
    end

    context "when no activity defines vocabulary" do
      it "returns a blank string" do
        expect(presenter.vocabulary).to eq("")
      end
    end
  end

  describe "#estimated_time" do
    def with_activity_times(*times)
      create(:document,
             metadata: { "subject" => "math", "grade" => "6" },
             activity_metadata: times.map { |t| { "activity-time" => t.to_s } })
    end

    it "rounds total activity time up to whole 45-minute class periods" do
      # 45 → 1 period
      expect(described_class.new(with_activity_times(20, 25)).estimated_time)
        .to eq("1 Class Period")
      # 60 → 2 periods
      expect(described_class.new(with_activity_times(30, 30)).estimated_time)
        .to eq("2 Class Periods")
      # 135 → 3 periods
      expect(described_class.new(with_activity_times(45, 45, 45)).estimated_time)
        .to eq("3 Class Periods")
    end

    it "falls back to the authored estimated-time when no activity has a time" do
      document = create(:document, metadata: {
        "subject" => "math", "grade" => "6", "estimated-time" => "Two weeks"
      })

      expect(described_class.new(document).estimated_time).to eq("Two weeks")
    end

    it "is blank when there is neither activity time nor an authored value" do
      document = create(:document, metadata: { "subject" => "math", "grade" => "6" })

      expect(described_class.new(document).estimated_time).to be_blank
    end
  end

  describe "#lesson_prep_heading" do
    context "when the lesson-prep table defines a time" do
      let(:document) do
        create(:document, metadata: {
          "subject" => "math",
          "grade" => "6",
          "lesson_prep" => { "lesson-prep-time" => "30" }
        })
      end

      it "appends it to the heading, like an activity heading" do
        expect(presenter.lesson_prep_heading).to eq("Lesson Preparation (30 minutes)")
      end
    end

    context "when the time is a single minute" do
      let(:document) do
        create(:document, metadata: {
          "subject" => "math",
          "grade" => "6",
          "lesson_prep" => { "lesson-prep-time" => "1" }
        })
      end

      it "renders the singular unit" do
        expect(presenter.lesson_prep_heading).to eq("Lesson Preparation (1 minute)")
      end
    end

    context "when no prep time is authored" do
      let(:document) do
        create(:document, metadata: {
          "subject" => "math",
          "grade" => "6",
          "lesson_prep" => { "lesson-prep-directions" => "<ol><li>Review slides</li></ol>" }
        })
      end

      it "returns the bare heading, with no empty parentheses" do
        expect(presenter.lesson_prep_heading).to eq("Lesson Preparation")
      end
    end

    context "when the lesson has no lesson-prep table at all" do
      it "returns the bare heading" do
        expect(presenter.lesson_prep_heading).to eq("Lesson Preparation")
      end
    end
  end

  describe "#lesson_prep_directions" do
    context "when the lesson defines preparation directions" do
      let(:document) do
        create(:document, metadata: {
          "subject" => "math",
          "grade" => "6",
          "lesson_prep" => { "lesson-prep-directions" => "<ol><li>Review slides</li></ol>" }
        })
      end

      it "returns the directions HTML" do
        expect(presenter.lesson_prep_directions).to eq("<ol><li>Review slides</li></ol>")
      end
    end

    context "when the lesson has no preparation directions" do
      it "is blank" do
        expect(presenter.lesson_prep_directions).to be_blank
      end
    end

    context "when the directions separate groups with a blank line" do
      let(:document) do
        create(:document, metadata: {
          "subject" => "math",
          "grade" => "6",
          "lesson_prep" => {
            "lesson-prep-directions" => %(<p><span style="font-weight:700">Session 1</span></p><ol><li>Chart “Our Observations.”</li></ol>) +
                                        %(<p style="height:11pt"></p><p><span style="font-weight:700">Session 2</span></p>)
          }
        })
      end

      it "keeps the blank line (a non-breaking space) and the authored formatting" do
        result = presenter.lesson_prep_directions

        expect(result).to include(%(<p style="height:11pt">\u00A0</p>), %(<span style="font-weight:700">Session 2</span>),
                                  "“Our Observations.”")
      end
    end

    context "when the directions reference a [material: id] token" do
      let!(:material) { create(:material, identifier: "10s.10.gg.l7.slides01") }
      let(:document) do
        create(:document, metadata: {
          "subject" => "math",
          "grade" => "6",
          "lesson_prep" => {
            "lesson-prep-directions" => "<ol><li>Review [material: 10S.10.GG.L7.Slides01].</li></ol>"
          }
        })
      end

      it "flags a token that matches no material" do
        document.metadata["lesson_prep"]["lesson-prep-directions"] = "<p>Review [material: Typo_01].</p>"

        expect(presenter.lesson_prep_directions)
          .to include(%(Review <span class="badge text-bg-danger">Unknown material: typo_01</span>.))
      end

      it "resolves the token to inline plain material text (case-insensitively)" do
        result = presenter.lesson_prep_directions

        expect(result).to include(%(<span class="o-ld-material">10s.10.gg.l7.slides01</span>))
        expect(result).not_to include("[material:")
      end
    end
  end

  describe "Overview bullets" do
    # All three bullets come from the lesson's OWN lesson-metadata: the author
    # writes the recap, the summary and the look-ahead in one table and all
    # three render in that lesson.
    let(:document) do
      create(:document, metadata: {
        "subject" => "science",
        "grade" => "10",
        "unit-id" => "GG",
        "lesson-number" => "7",
        "lesson-title" => "How does our stuff impact climate change?",
        "description" => "In this lesson, we will create a Class Final Explanatory Model.",
        "description-past" => "In the previous lesson, we created a Class Final Explanatory Model.",
        "description-future" => "In the next lesson, we will create a Class Final Explanatory Model."
      })
    end

    it "reads overview_past from this lesson's own description-past" do
      expect(presenter.overview_past)
        .to eq("In the previous lesson, we created a Class Final Explanatory Model.")
    end

    it "reads overview_future from this lesson's own description-future" do
      expect(presenter.overview_future)
        .to eq("In the next lesson, we will create a Class Final Explanatory Model.")
    end

    it "assembles the three bullets as previous, this, next" do
      bullets = [presenter.overview_past, presenter.description, presenter.overview_future]

      expect(bullets).to eq([
        "In the previous lesson, we created a Class Final Explanatory Model.",
        "In this lesson, we will create a Class Final Explanatory Model.",
        "In the next lesson, we will create a Class Final Explanatory Model."
      ])
    end

    # The lesson's curriculum position is irrelevant now — no neighbour is
    # consulted, so a lesson with no siblings still renders all three.
    it "renders all three even when the lesson stands alone in its unit" do
      expect([presenter.overview_past, presenter.description, presenter.overview_future])
        .to all(be_present)
    end

    context "when a description field is blank" do
      let(:document) do
        create(:document, metadata: {
          "subject" => "science",
          "grade" => "10",
          "unit-id" => "GG",
          "lesson-number" => "1",
          "description" => "In this lesson…",
          "description-past" => "",
          "description-future" => ""
        })
      end

      it "drops that bullet instead of rendering an empty one" do
        expect(presenter.overview_past).to be_nil
        expect(presenter.overview_future).to be_nil
        expect(presenter.description).to eq("In this lesson…")
      end
    end
  end

  describe "#overview_items" do
    let(:document) do
      create(:document, metadata: {
        "grade" => "3", "subject" => "math", "unit_id" => "1", "lesson_number" => "5",
        "description_past" => "<p>In the previous lesson, we compared.</p>",
        "description" => "<p>In this lesson, we graph.</p>",
        "description_future" => future
      })
    end

    context "when a cell was left blank in the source doc" do
      let(:future) { %(<p style="height:11pt;text-align:left"></p>) }

      it "drops it instead of rendering an empty bullet" do
        expect(presenter.overview_items).to eq ["<p>In the previous lesson, we compared.</p>", "<p>In this lesson, we graph.</p>"]
      end
    end

    context "when an entry holds only an image" do
      let(:future) { %(<p><img src="https://example.com/next.png"></p>) }

      it "keeps it" do
        expect(presenter.overview_items.size).to eq 3
      end
    end
  end
end
