# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tags::ImageTag do
  let!(:image) { create(:image, identifier: "1234bw20p") }
  let(:tag_value) { "1234BW20P, 80" }
  let(:paragraph) { "<p><span>This is centered.</span><br><span>[image:#{tag_value}]</span><br><span>It will look like this.</span></p>" }
  let(:context_type) { :default }
  let(:nodes) { Nokogiri::HTML.fragment(paragraph) }
  let(:opts) { { value: tag_value, context_type:, explicit_render: true } }
  let(:tag_node) { nodes.at_css("p") }
  let!(:tag) { described_class.new.parse(tag_node, opts) }
  let(:content) { Nokogiri::HTML.fragment(tag.content) }

  context "when sized over 50%" do
    it "centers the image at that percentage of the width, with the sheet's alt text" do
      img = content.at_css(".o-ld-image--center img")

      expect(img["style"]).to eq "width: 80%;"
      expect(img["src"]).to eq image.file_url
      expect(img["alt"]).to eq image.alt_text
    end

    it "shows the caption and credit from the sheet" do
      expect(content.at_css(".o-ld-image__caption").text).to eq "Image of a mountain scene."
      expect(content.at_css(".o-ld-image__credit").text).to eq "Used with permission from Ten Strands."
    end

    it "splits the paragraph around the image, dropping the line breaks at the cut" do
      expect(nodes.to_html.gsub(/\n\s*/, "")).to match(
        %r{\A<p><span>This is centered\.</span></p><div class="o-ld-image o-ld-image--center">.*</div><p><span>It will look like this\.</span></p>\z}
      )
    end

    context "when the tag is alone in its paragraph" do
      let(:paragraph) { "<p><span>[image:#{tag_value}]</span></p>" }

      it "replaces the paragraph with the image" do
        expect(nodes.to_html.strip).to start_with(%(<div class="o-ld-image o-ld-image--center">))
        expect(nodes.css("p:not([class])")).to be_empty
      end
    end

    context "when the tag sits in a list item" do
      let(:paragraph) { "<ul><li><span>Look: [image:#{tag_value}]</span></li></ul>" }
      let(:tag_node) { nodes.at_css("li") }

      it "places the image inside the item" do
        expect(nodes.at_css("li .o-ld-image--center")).to be_present
        expect(nodes.at_css("li").text).to include("Look:")
      end
    end

    context "without caption or credit" do
      let!(:image) { create(:image, identifier: "1234bw20p", caption: nil, credit: nil) }

      it "renders the image alone" do
        expect(content.at_css(".o-ld-image__caption, .o-ld-image__credit")).to be_nil
      end
    end
  end

  context "when sized 50% or less" do
    let(:tag_value) { "1234BW20P, 50" }
    let(:paragraph) { "<p><span>[image:#{tag_value}] This text wraps.</span></p>" }

    it "floats the image left inside the paragraph so the following text wraps" do
      expect(nodes.at_css("p > span > img.o-ld-image--wrap")["style"]).to eq "width: 50%;"
      expect(nodes.at_css("p").text).to eq " This text wraps."
    end

    it "omits the caption and credit but keeps the alt text" do
      expect(content.at_css(".o-ld-image__caption, .o-ld-image__credit")).to be_nil
      expect(content.at_css("img")["alt"]).to eq image.alt_text
    end
  end

  context "without a size" do
    let(:tag_value) { "1234bw20p" }

    it "uses the full width" do
      expect(content.at_css("img")["style"]).to eq "width: 100%;"
    end
  end

  context "with an unknown image id" do
    let(:tag_value) { "missing, 80" }

    it "shows an error badge in place of the tag" do
      expect(nodes.at_css(".badge").text).to eq "Unknown image: missing"
    end
  end

  it "escapes authored sheet text" do
    image.update!(caption: %(<script>alert(1)</script>), alt_text: %(x" onerror="alert(1)))
    rendered = Nokogiri::HTML.fragment(described_class.new.parse(Nokogiri::HTML.fragment(paragraph).at_css("p"), opts).content)

    expect(rendered.at_css("script")).to be_nil
    expect(rendered.at_css("img")["onerror"]).to be_nil
  end

  context "in the gdoc context" do
    let(:context_type) { :gdoc }

    it "passes the size to the Apps Script in the alt text and aligns with attributes" do
      expect(content.at_css("p.o-ld-image[align=center] img")["alt"]).to eq "[80] #{image.alt_text}"
      expect(content.at_css(".o-ld-image__caption")["align"]).to eq "right"
      expect(content.at_css(".o-ld-image__spacer")).to be_present
    end

    context "when sized 50% or less" do
      let(:tag_value) { "1234BW20P, 25" }

      it "keeps the image inline with its size marker and no caption" do
        expect(content.at_css("img")["alt"]).to eq "[25] #{image.alt_text}"
        expect(content.at_css(".o-ld-image__caption")).to be_nil
      end
    end
  end
end
