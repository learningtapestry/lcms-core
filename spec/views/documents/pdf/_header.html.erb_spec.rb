# frozen_string_literal: true

require "rails_helper"

describe "documents/pdf/_header", type: :view do
  let(:document) do
    create(:document, metadata: {
      "lesson_title" => "Common Method Bias",
      "grade" => "3",
      "unit_id" => "1",
      "section_number" => "1",
      "lesson_number" => "5",
      "subject" => "math",
      "lesson_type" => "AP"
    })
  end
  let(:presenter) { DocumentPresenter.new(document, content_type: :default) }

  before { Settings.set(:documents, "lesson_types" => { "AP" => "Anchoring Phenomenon" }) }

  def render_header
    render "documents/pdf/header", document: presenter
  end

  it "renders the Unit Title on the right of the banner strip" do
    render_header
    expect(rendered).to have_css("td.c-lesson-banner__unit", text: "Unit 1")
  end

  it "places the Unit Title above the Lesson Type" do
    render_header
    expect(rendered.index("c-lesson-banner__unit")).to be < rendered.index("c-lesson-banner__type")
  end

  it "renders the Lesson Type and Estimated Time lines" do
    render_header
    expect(rendered).to have_css("td.c-lesson-banner__type", text: "Anchoring Phenomenon")
    expect(rendered).to have_css("td.c-lesson-banner__time")
  end

  it "spans the brandmark cell across all three right-hand lines" do
    render_header
    expect(rendered).to have_css("td.c-lesson-banner__brand[rowspan='3']")
  end

  it "renders the Lesson Title below the divider, prefixed with the lesson number" do
    render_header
    expect(rendered).to have_css("hr.c-lesson-banner__divider")
    expect(rendered).to have_css("h1.c-lesson-banner__title", text: "Lesson 5: Common Method Bias")
  end

  context "when activities define vocabulary" do
    let(:document) do
      create(:document,
             metadata: {
               "lesson_title" => "Common Method Bias",
               "grade" => "3",
               "unit_id" => "1",
               "section_number" => "1",
               "lesson_number" => "5",
               "subject" => "math"
             },
             activity_metadata: [{ "vocabulary" => "observe, natural" }])
    end

    it "renders a bold label with the terms in italics" do
      render_header
      expect(rendered).to have_css("p.c-lesson-vocabulary strong", text: "Vocabulary:")
      expect(rendered).to have_css("p.c-lesson-vocabulary em", text: "observe, natural")
    end
  end

  context "when the lesson defines preparation directions and a prep time" do
    let(:document) do
      create(:document, metadata: {
        "lesson_title" => "Common Method Bias",
        "grade" => "3",
        "unit_id" => "1",
        "section_number" => "1",
        "lesson_number" => "5",
        "subject" => "math",
        "lesson_prep" => {
          "lesson-prep-time" => "30",
          "lesson-prep-directions" => "<ol><li>Review slides</li></ol>"
        }
      })
    end

    it "carries the prep time in the section heading" do
      render_header
      expect(rendered).to have_css("h2.c-lesson-prep__heading", text: "Lesson Preparation (30 minutes)")
    end
  end
end
