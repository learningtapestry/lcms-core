# frozen_string_literal: true

require "rails_helper"

# Every content tag renders the same way whichever kind of document it is
# authored in: a lesson, a material, or a metadata field rendered inline.
describe "Content tags across document types" do
  before do
    Rails.cache.clear
    create(:link, identifier: "nasa-01", url: "https://www.nasa.gov/", text: "NASA")
    create(:image, identifier: "map-01", alt_text: "Map", caption: "A map")
    create(:material, identifier: "worksheet-01", metadata: { "material-title" => "Worksheet" })
    create(:link, identifier: "deck-01", url: "https://docs.google.com/presentation/d/deck/edit")
    allow(SlideThumbnailService).to receive(:call).and_return(
      SlideThumbnailService::Result.new(image_url: "https://x.test/slide.png", slide_url: "https://docs.google.com/presentation/d/deck/edit#slide=id.p2")
    )
  end

  let(:body) do
    <<~HTML
      <p><span>Visit [url: nasa-01] and use [material: worksheet-01].</span></p>
      <p><span>[image: map-01, 80]</span></p>
      <p><span>[slide: deck-01, 2]</span></p>
      <table><tr><td><p><span>[callout]</span></p></td><td></td></tr>
      <tr><td><p><span>type</span></p></td><td><p><span>tip</span></p></td></tr>
      <tr><td><p><span>text</span></p></td><td><p><span>Try [url: nasa-01].</span></p></td></tr></table>
      <p><span>After.</span></p>
    HTML
  end

  let(:lesson_html) do
    <<~HTML
      <html><body>
      <table><tr><td><p><span>lesson-metadata</span></p></td><td></td></tr>
      <tr><td><p><span>subject</span></p></td><td><p><span>science</span></p></td></tr>
      <tr><td><p><span>grade</span></p></td><td><p><span>k</span></p></td></tr></table>
      #{body}
      </body></html>
    HTML
  end

  let(:material_html) do
    <<~HTML
      <html><body>
      <table><tr><td><p><span>material-metadata</span></p></td><td></td></tr>
      <tr><td><p><span>material-id</span></p></td><td><p><span>handout-01</span></p></td></tr>
      <tr><td><p><span>material-title</span></p></td><td><p><span>Handout</span></p></td></tr></table>
      #{body}
      </body></html>
    HTML
  end

  def rendered(record_class, presenter_class, html, type, context_type)
    template = DocTemplate::Template.parse(html, type:)
    expect(template.documents.values.flat_map(&:errors)).to be_empty
    record = record_class == Document ? create(:document) : create(:material, identifier: "handout-01")
    record.document_parts.delete_all
    record.create_parts_for(template)
    presenter_class.new(record.reload).content_for(context_type)
  end

  shared_examples "renders every tag" do
    it "renders the link, material, image and callout in place" do
      expect(output).to match(%r{Visit <a href="https://www.nasa.gov/"[^>]*>NASA</a>})
      expect(output).to include(%(<span class="o-ld-material">Worksheet</span>))
      expect(output).to include("o-ld-image__img")
      expect(output).to match(%r{<a href="https://docs.google.com/presentation/d/deck/edit#slide=id.p2"[^>]*><img class="o-ld-slide__img" src="https://x.test/slide.png"})
      expect(output).to include("A map")
      expect(output).to include("o-ld-callout--inline", "TEACHING TIP")
      expect(output).to match(%r{Try <a href="https://www.nasa.gov/"[^>]*>NASA</a>})
      expect(output).not_to match(/\{\{|\[(url|image|material|callout|slide)/)
      expect(output.index("o-ld-callout")).to be < output.index("After.")
    end
  end

  %i(default gdoc).each do |context_type|
    context "in a lesson (#{context_type})" do
      let(:output) { rendered(Document, DocumentPresenter, lesson_html, :document, context_type) }

      it_behaves_like "renders every tag"
    end

    context "in a material (#{context_type})" do
      let(:output) { rendered(Material, MaterialPresenter, material_html, :material, context_type) }

      it_behaves_like "renders every tag"
    end

    context "in a metadata field (#{context_type})" do
      let(:output) { DocTemplate::InlineTags.render(body, context_type:) }

      it_behaves_like "renders every tag"
    end
  end
end
