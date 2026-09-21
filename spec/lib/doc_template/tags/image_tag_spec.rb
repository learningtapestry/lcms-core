# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tags::ImageTag do
  let(:node) do
    html = Nokogiri::HTML original_content
    html.at_xpath("*//table/thead/tr[1]/td[1]")
  end
  let(:metadata) { { "grade" => "5", "unit" => "1", "subject" => "Math" } }
  let(:value) { "example_image" }
  let(:opts) { { value:, metadata: } }
  let(:original_content) do
    <<-HTML
      <table>
        <thead>
          <tr><td>[#{described_class::TAG_NAME}]</td></tr>
          <tr><td>Caption text</td></tr>
          <tr><td>Credit text</td></tr>
        </thead>
      </table>
    HTML
  end
  let(:tag) { described_class.new }
  subject { tag.parse(node, opts) }

  describe "#parse_table" do
    it "removes original node" do
      expect(subject.content).to_not include("[#{described_class::TAG_NAME}]")
    end

    it "substitues tag with image with caption" do
      expect(subject.content).to include("figcaption>Caption text</figcaption>")
    end

    it "defaults to centered, large layout" do
      expect(subject.content).to include("o-ld-image--center")
      expect(subject.content).to include("o-ld-image--large")
    end

    it "renders the credit row for centered images" do
      expect(subject.content).to include('class="o-ld-image__credit">Credit text')
    end

    it "builds the image src from the first token only" do
      expect(subject.content).to include("example_image.jpg")
    end

    it "uses the caption as alt text" do
      expect(subject.content).to include('alt="Caption text"')
    end
  end

  # BaseTag#parse_template uses plain ERB (no auto-escaping), and HtmlSanitizer's
  # allowlist pass only runs over the SOURCE doc, never over rendered template
  # output — so authored text has to be neutralised here or it reaches stored,
  # publicly served HTML intact.
  describe "escaping of authored caption/credit text" do
    # The credit cell is entity-encoded in the source so that cell_text's
    # `.text` DECODES it into real angle brackets — that is the shape that
    # actually injects. A literal <script> in the fixture would be parsed as an
    # element by Nokogiri and stripped by `.text` before it ever reached us.
    let(:original_content) do
      <<-HTML
        <table>
          <thead>
            <tr><td>[#{described_class::TAG_NAME}]</td></tr>
            <tr><td>x" onerror="alert(1)</td></tr>
            <tr><td>Ben &amp; Co &lt;script&gt;alert(2)&lt;/script&gt;</td></tr>
          </thead>
        </table>
      HTML
    end

    it "does not let a caption break out of the alt attribute" do
      img = Nokogiri::HTML.fragment(subject.content).at_css("img")

      expect(img["onerror"]).to be_nil
      expect(img["alt"]).to eq('x" onerror="alert(1)')
    end

    it "does not let a credit inject markup into the document body" do
      doc = Nokogiri::HTML.fragment(subject.content)

      expect(doc.at_css("script")).to be_nil
      expect(doc.at_css("p.o-ld-image__credit").text).to eq("Ben & Co <script>alert(2)</script>")
    end
  end

  describe "alignment and size args" do
    context "when size is specified" do
      let(:value) { "example_image size=medium" }

      it "applies the size modifier" do
        expect(subject.content).to include("o-ld-image--medium")
      end

      it "still builds the src from the id only (ignores args)" do
        expect(subject.content).to include("example_image.jpg")
        expect(subject.content).not_to include("size=medium.jpg")
      end
    end

    %w(left right).each do |align|
      context "when aligned #{align}" do
        let(:value) { "example_image align=#{align}" }

        it "applies the #{align} float modifier" do
          expect(subject.content).to include("o-ld-image--#{align}")
        end

        it "suppresses the caption and credit (text wraps instead)" do
          expect(subject.content).not_to include("figcaption")
          expect(subject.content).not_to include("o-ld-image__credit")
        end

        it "still emits alt text from the caption" do
          expect(subject.content).to include('alt="Caption text"')
        end
      end
    end

    context "when align is centered explicitly" do
      let(:value) { "example_image align=center size=small" }

      it "keeps the caption and credit" do
        expect(subject.content).to include("figcaption>Caption text</figcaption>")
        expect(subject.content).to include("o-ld-image__credit")
      end

      it "applies center and small modifiers" do
        expect(subject.content).to include("o-ld-image--center")
        expect(subject.content).to include("o-ld-image--small")
      end
    end

    context "when an unrecognized value is given" do
      let(:value) { "example_image align=sideways size=huge" }

      it "falls back to center/large defaults" do
        expect(subject.content).to include("o-ld-image--center")
        expect(subject.content).to include("o-ld-image--large")
      end
    end
  end

  describe "gdoc template" do
    let(:opts) { { value:, metadata:, context_type: :gdoc } }
    let(:doc) { Nokogiri::HTML.fragment subject.content }

    it "keeps the o-simple-table marker" do
      # HtmlSanitizer#post_processing_tables_gdoc keys off
      # `table:not(.o-simple-table)` to skip the generic border/padding pass.
      expect(doc.at_css("table")["class"]).to include("o-simple-table")
    end

    it "stacks image, caption and credit in one column" do
      rows = doc.css("tr")
      expect(rows.size).to eq(3)
      expect(rows.map { |row| row.css("td").size }).to all(eq(1))
      expect(rows[0].at_css("img")).to be_present
      expect(rows[1].at_css("p.o-ld-image__caption").text).to eq("Caption text")
      expect(rows[2].at_css("p.o-ld-image__credit").text).to eq("Credit text")
    end

    it "puts the typography class on the paragraph, not the cell" do
      # Google Docs' import drops cell-level text formatting, so a class on the
      # <td> would lose the caption's size and alignment.
      expect(doc.at_css("td.o-ld-image__caption")).to be_nil
      expect(doc.at_css("p.o-ld-image__caption")).to be_present
    end

    it "puts the credit rule on the cell, which survives the import" do
      expect(doc.at_css("td.o-ld-image__credit-cell")).to be_present
    end

    it "emits alt text" do
      expect(doc.at_css("img")["alt"]).to eq("Caption text")
    end

    context "when the caption and credit cells are empty" do
      let(:original_content) do
        <<-HTML
          <table>
            <thead>
              <tr><td>[#{described_class::TAG_NAME}]</td></tr>
              <tr><td></td></tr>
              <tr><td></td></tr>
            </thead>
          </table>
        HTML
      end

      it "renders only the image row" do
        expect(doc.css("tr").size).to eq(1)
        expect(doc.at_css("p.o-ld-image__caption")).to be_nil
        expect(doc.at_css("td.o-ld-image__credit-cell")).to be_nil
      end
    end

    context "when the image is not centered" do
      let(:value) { "example_image align=left" }

      it "renders only the image row" do
        expect(doc.css("tr").size).to eq(1)
        expect(doc.at_css("p.o-ld-image__caption")).to be_nil
        expect(doc.at_css("p.o-ld-image__credit")).to be_nil
      end

      it "still emits alt text" do
        expect(doc.at_css("img")["alt"]).to eq("Caption text")
      end
    end
  end
end
