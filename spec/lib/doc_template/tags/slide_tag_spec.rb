# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tags::SlideTag do
  let(:deck_url) { "https://docs.google.com/presentation/d/deck123/edit" }
  let(:result) do
    SlideThumbnailService::Result.new(image_url: "https://bucket.s3.amazonaws.com/uploads/slides/a.png",
                                      slide_url: "https://docs.google.com/presentation/d/deck123/edit#slide=id.p3")
  end
  let(:tag) { described_class.new }
  let(:fragment) { Nokogiri::HTML.fragment(html) }
  let(:node) { fragment.at_css("p") }
  let(:html) { "<p><span>[slide: #{value}]</span></p>" }
  let(:value) { "Deck-01, 3" }
  let(:context_type) { :default }

  subject(:parsed) { tag.parse(node, value:, context_type:, explicit_render: true) }

  before do
    Current.reset
    create(:link, identifier: "deck-01", url: deck_url, text: "Badger Photos")
    allow(SlideThumbnailService).to receive(:call).with(deck_url, 3).and_return(result)
  end

  it "links the slide's thumbnail to the slide, at half the width by default" do
    expect(parsed.content).to include(%(<a href="#{result.slide_url}"><img class="o-ld-slide__img" src="#{result.image_url}"))
    expect(parsed.content).to include(%(alt="Slide 3 of Badger Photos"), "width: 50%;")
    expect(parsed.errors).to be_empty
  end

  context "with a size" do
    let(:value) { "deck-01, 3, 80" }

    it "uses it as the width" do
      expect(parsed.content).to include("width: 80%;")
    end
  end

  context "in the Google Doc" do
    let(:context_type) { :gdoc }

    it "carries the size in the alt text for the Apps Script" do
      expect(parsed.content).to include(%(alt="[50] Slide 3 of Badger Photos"))
      expect(parsed.content).to include(%(<p class="o-ld-slide" align="left">))
    end
  end

  context "when the deck id is unknown" do
    let(:value) { "nope, 3" }

    it "shows a red placeholder, unlinked, and warns" do
      expect(parsed.content).to include(%(src="#{described_class::PLACEHOLDER_SRC}"))
      expect(parsed.content).not_to include("<a ")
      expect(parsed.errors).to contain_exactly(/red placeholder: unknown slide deck id 'nope'/)
    end
  end

  context "when the thumbnail cannot be produced" do
    before do
      allow(SlideThumbnailService).to receive(:call).and_raise(SlideThumbnailService::Error, "the deck has no slide 3")
    end

    it "shows a red placeholder and warns" do
      expect(parsed.content).to include(%(src="#{described_class::PLACEHOLDER_SRC}"))
      expect(parsed.errors).to contain_exactly(/the deck has no slide 3/)
    end
  end

  context "inside a paragraph" do
    let(:html) { "<p><span>Look at this: [slide: deck-01, 3] then discuss.</span></p>" }

    it "stands on its own lines between the paragraph's halves" do
      parsed

      expect(fragment.to_html).to match(%r{\A<p><span>Look at this: </span></p><div class="o-ld-slide">.*</div>\s*<p><span> then discuss.</span></p>\z}m)
    end
  end

  it "asks for each slide once while a document is parsed for every context" do
    html = <<~HTML
      <html><body>
      <table><tr><td><p><span>lesson-metadata</span></p></td><td></td></tr>
      <tr><td><p><span>subject</span></p></td><td><p><span>science</span></p></td></tr></table>
      <p><span>[slide: deck-01, 3]</span></p>
      </body></html>
    HTML
    DocTemplate::Template.parse(html)

    expect(SlideThumbnailService).to have_received(:call).once
  end
end
