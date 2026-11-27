# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::HtmlList do
  describe ".split" do
    def split(html) = described_class.split(html)

    it "splits on commas inside a styled run and re-wraps each piece" do
      html = %(<p><span style="font-style:italic">Wonder Walkers</span><span> by Micha Archer, [material: ws01]</span></p>)

      expect(split(html)).to eq [
        %(<span style="font-style:italic">Wonder Walkers</span><span> by Micha Archer</span>),
        "<span>[material: ws01]</span>"
      ]
    end

    it "treats semicolons, line breaks and paragraphs as separators too" do
      expect(split("<p>Chart paper; tape</p><p>markers<br>glue</p>")).to eq ["Chart paper", "tape", "markers", "glue"]
    end

    it "drops blank entries, including empty paragraphs and trailing commas" do
      expect(split(%(<p>Chart paper, </p><p style="height:11pt"></p><p> , </p>))).to eq ["Chart paper"]
    end

    it "escapes text and keeps an entry made of an image" do
      expect(split(%(<p>Beakers &lt;250ml&gt; &amp; tongs, <img src="https://x.test/a.png"></p>)))
        .to eq ["Beakers &lt;250ml&gt; &amp; tongs", %(<img src="https://x.test/a.png">)]
    end

    it "keeps nested formatting" do
      html = %(<p><a href="https://x.test"><span style="font-weight:700">Lab, guide</span></a></p>)

      expect(split(html)).to eq [
        %(<a href="https://x.test"><span style="font-weight:700">Lab</span></a>),
        %(<a href="https://x.test"><span style="font-weight:700">guide</span></a>)
      ]
    end
  end
end
