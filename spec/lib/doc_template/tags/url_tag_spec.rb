# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tags::UrlTag do
  let(:tag) { described_class.new }
  let(:fragment) { Nokogiri::HTML.fragment(%(<p>Visit <span style="font-weight:700">[url: #{value}]</span> today.</p>)) }
  let(:node) { fragment.at_xpath(".//p") }
  let(:value) { "NASA-01," }

  subject(:parsed) { tag.parse(node, value:, explicit_render: true) }

  context "when the sheet row has text" do
    before { create(:link, identifier: "nasa-01", url: "https://www.nasa.gov/", text: "NASA website") }

    it "links the text in place, keeping the surrounding sentence and formatting" do
      parsed

      expect(fragment.to_html).to eq(
        %(<p>Visit <span style="font-weight:700"><a href="https://www.nasa.gov/">NASA website</a></span> today.</p>)
      )
      expect(parsed.errors).to be_empty
    end
  end

  context "when the sheet row has no text" do
    before { create(:link, identifier: "nasa-01", url: "https://www.nasa.gov/?a=1&b=2") }

    it "shows the URL itself as the link" do
      expect(parsed.content).to eq %(<a href="https://www.nasa.gov/?a=1&amp;b=2">https://www.nasa.gov/?a=1&amp;b=2</a>)
    end
  end

  context "when the sheet text has markup" do
    before { create(:link, identifier: "nasa-01", text: "<b>NASA</b>") }

    it "escapes it" do
      expect(parsed.content).to include(">&lt;b&gt;NASA&lt;/b&gt;</a>")
    end
  end

  context "when the id is unknown" do
    let(:value) { "Typo-01" }

    it "renders a red badge with the id" do
      expect(parsed.content).to eq %(<span class="badge text-bg-danger">Unknown URL: typo-01</span>)
    end
  end

  it "is picked up when a document is parsed" do
    create(:link, identifier: "nasa-01", url: "https://www.nasa.gov/", text: "NASA website")
    html = <<~HTML
      <html><body>
      <table><tr><td><p><span>lesson-metadata</span></p></td><td></td></tr>
      <tr><td><p><span>subject</span></p></td><td><p><span>science</span></p></td></tr>
      <tr><td><p><span>grade</span></p></td><td><p><span>k</span></p></td></tr></table>
      <p><span>See [url: nasa-01,] for more.</span></p>
      </body></html>
    HTML

    template = DocTemplate::Template.parse(html)
    # The tag renders behind a placeholder that the document part fills in.
    part = template.parts.find { template.render.include?(it[:placeholder].to_s) }

    expect(part[:content]).to match(%r{<a href="https://www.nasa.gov/"[^>]*>NASA website</a>})
  end
end
