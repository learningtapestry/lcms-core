# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::InlineTags do
  before { create(:link, identifier: "nasa-01", url: "https://www.nasa.gov/", text: "NASA") }

  describe ".render" do
    it "renders the tags in place, keeping the field's formatting" do
      html = %(<p><span>See [url: nasa-01] and </span><span style="font-weight:700">bold</span></p>) +
             %(<ul><li><span>[material: missing-01]</span></li></ul>)

      expect(described_class.render(html).delete("\n")).to eq(
        %(<p><span>See <a href="https://www.nasa.gov/">NASA</a> and </span><span style="font-weight:700">bold</span></p>) +
        %(<ul><li><span><span class="badge text-bg-danger">Unknown material: missing-01</span></span></li></ul>)
      )
    end

    it "renders a tag in text that is not wrapped in a span" do
      expect(described_class.render("<p>See [url: nasa-01].</p>")).to eq %(<p>See <a href="https://www.nasa.gov/">NASA</a>.</p>)
    end

    it "renders a tag for the requested context type" do
      create(:image, identifier: "map-01", alt_text: "Map")
      html = "<p><span>[image: map-01, 80]</span></p>"

      expect(described_class.render(html, context_type: :gdoc)).to include(%(alt="[80] Map"))
      expect(described_class.render(html)).to include(%(alt="Map"))
    end

    it "flags an unknown tag" do
      expect(described_class.render("<p><span>[bogus: x]</span></p>"))
        .to eq %(<p><span class="badge text-bg-danger">Unknown tag: bogus: x</span></p>)
    end

    it "leaves a field without tags, or with an unclosed bracket, as authored" do
      expect(described_class.render("<p>No tags</p>")).to eq "<p>No tags</p>"
      expect(described_class.render("<p>a [ b</p>")).to eq "<p>a [ b</p>"
      expect(described_class.render(nil)).to eq ""
    end
  end

  describe ".render_text" do
    it "escapes the text so only the tags become markup" do
      expect(described_class.render_text("Beaker <250 ml>, [url: nasa-01]"))
        .to eq %(Beaker &lt;250 ml&gt;, <a href="https://www.nasa.gov/">NASA</a>)
    end
  end
end
