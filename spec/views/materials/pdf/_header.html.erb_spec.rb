# frozen_string_literal: true

require "rails_helper"

describe "materials/pdf/_header", type: :view do
  let(:material) do
    Material.new(metadata: { "material-title" => "Document Title", "material-type" => "handout" })
  end
  let(:presenter) { MaterialPresenter.new(material, content_type: :default) }

  def render_header
    render "materials/pdf/header", document: presenter
  end

  it "renders the Material Type (titleized) on the right of the banner strip" do
    render_header
    expect(rendered).to have_css("td.c-lesson-banner__type", text: "Handout")
  end

  it "renders the banner divider" do
    render_header
    expect(rendered).to have_css("hr.c-lesson-banner__divider")
  end

  it "renders the Document Title from material-title" do
    render_header
    expect(rendered).to have_css("h1.c-lesson-banner__title", text: "Document Title")
  end

  it "inlines the brandmark image when configured" do
    Settings.set(:documents, "brandmark" => "https://example.com/logo.png")
    allow(AssetHelper).to receive(:inline_data_uri).and_return("data:image/png;base64,AAAA")

    render_header
    expect(rendered).to have_css("img.c-lesson-banner__brand-img[src^='data:image/png']")
  end

  it "does not render the Name/Date row by default" do
    render_header
    expect(rendered).not_to have_css("table.o-m-namedate")
  end

  context "when material-metadata name-date is Yes" do
    let(:material) do
      Material.new(metadata: {
        "material-title" => "Document Title", "material-type" => "handout", "name-date" => "Yes"
      })
    end

    it "renders the Name/Date fill-in row" do
      render_header
      expect(rendered).to have_css("table.o-m-namedate td.o-m-namedate__label", text: "Name:")
      expect(rendered).to have_css("table.o-m-namedate td.o-m-namedate__label", text: "Date:")
    end

    it "places the Name/Date row above the Document Title" do
      render_header
      expect(rendered.index("o-m-namedate")).to be < rendered.index("c-lesson-banner__title")
    end
  end
end
