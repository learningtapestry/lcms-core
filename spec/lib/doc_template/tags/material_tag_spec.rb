# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tags::MaterialTag do
  let(:tag) { described_class.new }
  let(:fragment) { Nokogiri::HTML.fragment(html) }
  let(:node) { fragment.at_xpath(".//p") }

  describe "#parse" do
    let(:html) { %(<p>provide copies of <span>[material: #{identifier}]</span>.</p>) }
    let(:identifier) { "10s.10.gg.l7.worksheet01" }

    subject(:parsed) { tag.parse(node, value: identifier) }

    context "when the material exists" do
      let!(:material) { create(:material, identifier: identifier) }

      it "renders the material as plain text, not a link" do
        expect(parsed.content).to include(%(<span class="o-ld-material">#{identifier}</span>))
        expect(parsed.content).not_to include("href")
      end

      it "leaves no errors" do
        expect(parsed.errors).to be_empty
      end
    end

    context "when the material has an authored title" do
      let!(:material) do
        create(:material, identifier: identifier, metadata: { "material-title" => "Lesson 7 Slides" })
      end

      it "uses the material title as the visible text" do
        expect(parsed.content).to include(%(<span class="o-ld-material">Lesson 7 Slides</span>))
        expect(parsed.content).not_to include("href")
      end
    end

    context "when the material does not exist" do
      it "renders a red badge with the identifier" do
        expect(parsed.content).to include("badge text-bg-danger")
        expect(parsed.content).to include("Unknown material: #{identifier}")
      end

      it "does not report an error" do
        expect(parsed.errors).to be_empty
      end
    end

    # `[material: id]` is authored mid-sentence, and DocTemplate::Document hands
    # a tag its `node.parent` — so substituting the enclosing element would take
    # the sentence with it.
    describe "inline substitution" do
      it "replaces only the tag, keeping the text around it" do
        parsed
        expect(node.to_html).to eq(%(<p>provide copies of <span>#{parsed.placeholder}</span>.</p>))
      end

      it "keeps the enclosing element itself" do
        parsed
        expect(fragment.at_xpath(".//p")).to be_present
      end

      context "when the tag is the element's only content" do
        let(:html) { %(<p><span>[material: #{identifier}]</span></p>) }

        it "still substitutes in place" do
          parsed
          expect(node.to_html).to eq(%(<p><span>#{parsed.placeholder}</span></p>))
        end
      end

      # An attribute can hold brackets of its own (Google Docs carries authored
      # image alt text through the sanitizer). Matching serialized HTML would
      # hit that literal first and rewrite the attribute instead of the tag.
      context "when an attribute contains a bracketed literal" do
        let(:html) { %(<p><img alt="Figure [1]"> copies of [material: #{identifier}] now.</p>) }

        it "substitutes the tag, not the attribute" do
          parsed
          expect(node.at_xpath(".//img")["alt"]).to eq("Figure [1]")
          expect(node.text).to eq(" copies of #{parsed.placeholder} now.")
        end
      end

      context "when the surrounding text contains markup characters" do
        let(:html) { %(<p>use &lt;250ml&gt; beakers &amp; [material: #{identifier}] now.</p>) }

        it "keeps that text escaped" do
          parsed
          expect(node.to_html).to include("use &lt;250ml&gt; beakers &amp; #{parsed.placeholder} now.")
        end
      end

      context "when a broken export splits the tag across spans" do
        let(:html) { %(<p>copies of <span>[mat</span><span>erial: #{identifier}]</span> now.</p>) }

        it "substitutes the whole tag and keeps the surrounding text" do
          parsed
          expect(node.text).to eq("copies of #{parsed.placeholder} now.")
        end
      end
    end
  end

  # Google Docs splits one logical list into several `<ol>` chunks and carries
  # the running count in `start="N"`. Dropping an `<li>` leaves its chunk short
  # while the next chunk keeps its original absolute number, so the numbering
  # visibly skips. See the regression this guards in HtmlSanitizer's pipeline.
  describe "numbering across split lists" do
    let(:html) do
      <<~HTML.strip
        <ol start="1"><li><span>First.</span></li></ol>
        <ol start="2"><li><span>Display </span><span>Slide 4. Hand out </span><span>[material: mat.01]</span><span>.</span></li></ol>
        <ol start="3"><li><span>Third.</span></li></ol>
      HTML
    end
    let(:document) { DocTemplate::Document.parse(Nokogiri::HTML.fragment(html), context_type: "default") }

    def rendered
      index = document.parts.to_h { |p| [p[:placeholder], { content: p[:content], optional: p[:optional] }] }
      DocumentRenderer::Part.call(document.render, parts_index: index, with_optional: true)
    end

    it "leaves every list chunk with its item, so `start` stays in step" do
      counts = Nokogiri::HTML.fragment(rendered).css("ol").map { |ol| [ol["start"], ol.xpath("./li").size] }
      expect(counts).to eq([["1", 1], ["2", 1], ["3", 1]])
    end

    it "keeps the text authored alongside the tag" do
      expect(Nokogiri::HTML.fragment(rendered).text).to include("Display Slide 4. Hand out")
    end
  end
end
