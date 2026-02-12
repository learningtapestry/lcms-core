# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tags::LatexTag do
  let(:node) do
    html = Nokogiri::HTML original_content
    html.at_xpath("*//ol")
  end
  let(:options) { { value: } }
  let(:original_content) do
    <<-HTML
      <ol class="lst-kix_q3dubtijti3v-1" start="2" style="padding:0;margin:0">
        <li>
          <span style="font-size:8pt;font-family:&quot;Calibri&quot;;color:#231f20;font-weight:400">&nbsp;are
          [latex: \overleftrightarrow{CD}] intersecting lines. &nbsp;In a complete sentence, describe the angle
          relationship in the diagram. &nbsp;Write an equation for the angle relationship shown in the figure and
          solve for </span>
        </li>
      </ol>
    HTML
  end
  let(:svg) { "<svg>Test</svg>" }
  let(:tag) { described_class.new }
  let(:tag_name) { described_class::TAG_NAME }
  let(:value) { '\overleftrightarrow{CD}' }

  subject { tag.parse(node, options).render }

  describe "constants" do
    it "defines S3_FOLDER" do
      expect(described_class::S3_FOLDER).to eq "documents-latex-equations"
    end

    it "defines TAG_NAME" do
      expect(described_class::TAG_NAME).to eq "latex"
    end
  end

  describe "#parse" do
    before do
      allow(EmbedEquations).to receive(:tex_to_svg).with(value, preserve_color: false).and_return(svg)
    end

    it "removes original tag" do
      expect(subject).not_to include("[#{tag_name}]")
    end

    it "stores tag data" do
      expect(tag.parse(node, options).tag_data).to eq(latex: value)
    end

    context "with default context" do
      it "substitutes tag with inlined SVG" do
        expect(subject).to include svg
      end

      it "calls EmbedEquations.tex_to_svg" do
        subject
        expect(EmbedEquations).to have_received(:tex_to_svg).with(value, preserve_color: false)
      end
    end

    context "with gdoc context" do
      let(:s3_url) { "https://s3.amazonaws.com/bucket/documents-latex-equations/abc123.png" }
      let(:png_data) { "fake png binary data" }

      before do
        options[:context_type] = :gdoc
        allow_any_instance_of(described_class).to receive(:generate_image).and_yield(png_data)
        allow(S3Service).to receive(:upload).and_return(s3_url)
      end

      it "uploads PNG to S3 with correct parameters" do
        subject
        expect(S3Service).to have_received(:upload).with(
          a_string_matching(%r{^documents-latex-equations/[a-f0-9]{40}\.png$}),
          png_data,
          content_type: "image/png"
        )
      end

      it "substitutes tag with img element pointing to S3" do
        expect(subject).to include %(<img class="o-ld-latex" src="#{s3_url}">)
      end
    end

    context "when error occurs" do
      before do
        allow(EmbedEquations).to receive(:tex_to_svg).and_raise(StandardError, "conversion failed")
      end

      it "raises error in test environment" do
        expect { subject }.to raise_error(StandardError, "conversion failed")
      end

      context "in non-test environment" do
        before do
          allow(Rails.env).to receive(:test?).and_return(false)
          allow(Rails.logger).to receive(:warn)
        end

        it "logs warning and returns error message" do
          expect(subject).to include "Error converting Latex expression: #{value}"
          expect(Rails.logger).to have_received(:warn).with(/conversion failed.*Error converting Latex expression/)
        end
      end
    end

    context "with parent_node containing callout" do
      let(:parent_node) { '<div class="o-ld-callout">content</div>' }

      before do
        options[:parent_node] = parent_node
        allow(EmbedEquations).to receive(:tex_to_svg).with(value, preserve_color: true).and_return(svg)
      end

      it "preserves color when inside callout" do
        subject
        expect(EmbedEquations).to have_received(:tex_to_svg).with(value, preserve_color: true)
      end
    end

    context "with parent_node not containing callout" do
      let(:parent_node) { '<div class="o-ld-section">content</div>' }

      before do
        options[:parent_node] = parent_node
        allow(EmbedEquations).to receive(:tex_to_svg).with(value, preserve_color: false).and_return(svg)
      end

      it "does not preserve color when not inside callout" do
        subject
        expect(EmbedEquations).to have_received(:tex_to_svg).with(value, preserve_color: false)
      end
    end
  end

  describe "#generate_image" do
    let(:svg_content) { "<svg>equation</svg>" }
    let(:png_content) { "PNG binary content" }
    let(:custom_color) { "#ff0000" }

    before do
      allow(EmbedEquations).to receive(:tex_to_svg).and_return(svg_content)
      allow_any_instance_of(described_class).to receive(:system).with("svgexport", anything, anything).and_return(true)
    end

    it "converts SVG to PNG using svgexport" do
      tag.parse(node, options)
      expect_any_instance_of(described_class).to receive(:system).with(
        "svgexport",
        a_string_matching(/tex-eq.*\.svg/),
        a_string_matching(/tex-eq.*\.png/)
      )

      tag.send(:generate_image) { |_png| }
    end
  end
end
