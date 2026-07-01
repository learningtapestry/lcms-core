# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tags::CalloutTag do
  let(:metadata) { instance_double(DocTemplate::Objects::Lesson, subject: "math") }
  let(:opts) { { metadata:, context_type: :default } }
  let(:tag) { described_class.new }
  let(:node) do
    html = Nokogiri::HTML(original_content)
    html.at_xpath("*//td[contains(., '[#{described_class::TAG_NAME}')]")
  end

  subject { tag.parse(node, opts).content }

  describe "legacy 3-row 1-col shape (renders with inline visual + default + icon)" do
    let(:original_content) do
      <<-HTML
        <table>
          <tr><td>[#{described_class::TAG_NAME}: math]</td></tr>
          <tr><td>Header Text</td></tr>
          <tr><td>Body <strong>content</strong></td></tr>
        </table>
      HTML
    end

    it "renders the inline horizontal callout layout" do
      expect(subject).to include("o-ld-callout--inline")
      expect(subject).to include("o-ld-callout__label")
      expect(subject).to include("o-ld-callout__body")
    end

    it "renders the default + icon and the type label" do
      expect(subject).to include("o-ld-callout__icon")
      expect(subject).to include("o-ld-callout__type")
      expect(subject).to include("Header Text")
    end

    it "preserves the body content HTML" do
      expect(subject).to include("Body <strong>content</strong>")
    end
  end

  describe "3-row 2-col labeled shape (type/text labels in col 1)" do
    let(:original_content) do
      <<-HTML
        <table>
          <tr><td colspan="2">[#{described_class::TAG_NAME}]</td></tr>
          <tr><td>type</td><td>ATTENDING TO STUDENT IDEAS</td></tr>
          <tr><td>text</td><td>If there is time, review and celebrate students' learning.</td></tr>
        </table>
      HTML
    end

    it "renders the value column as the type label, not the label column" do
      expect(subject).to include("ATTENDING TO STUDENT IDEAS")
      expect(subject).to include("If there is time, review and celebrate students' learning.")
      expect(subject).to include("o-ld-callout__type")
    end

    it "renders with inline visual + default + icon" do
      expect(subject).to include("o-ld-callout--inline")
      expect(subject).to include("o-ld-callout__icon")
    end
  end

  describe "new 1-row 2-col inline shape" do
    let(:original_content) do
      <<-HTML
        <table>
          <tr>
            <td><p>[#{described_class::TAG_NAME}: math]</p><p>&#10133;</p><p>Callout Type</p></td>
            <td><p>Body content goes here</p></td>
          </tr>
        </table>
      HTML
    end

    it "renders the inline callout template" do
      expect(subject).to include("o-ld-callout--inline")
      expect(subject).to include("o-ld-callout__label")
      expect(subject).to include("o-ld-callout__body")
    end

    it "strips the [callout: ...] marker from the label cell" do
      expect(subject).not_to include("[#{described_class::TAG_NAME}: math]")
    end

    it "preserves the icon and label HTML in the label cell" do
      expect(subject).to include("Callout Type")
      expect(subject).to include("&#10133;").or include("➕")
    end

    it "preserves the body cell HTML" do
      expect(subject).to include("Body content goes here")
    end
  end

  describe "typed callouts ([callout: <type>] -> canonical title)" do
    described_class::CALLOUT_TYPES.each do |type, title|
      context "when the callout type is #{type}" do
        let(:original_content) do
          <<-HTML
            <table>
              <tr>
                <td><p>[#{described_class::TAG_NAME}: #{type}]</p></td>
                <td><p>Body content for #{type}.</p></td>
              </tr>
            </table>
          HTML
        end

        it "renders the canonical #{title.inspect} title" do
          expect(subject).to include(title)
          expect(subject).to include("o-ld-callout__type")
        end

        it "adds the o-ld-callout--#{type} modifier and an icon" do
          expect(subject).to include("o-ld-callout--#{type}")
          expect(subject).to include("o-ld-callout__icon--#{type}")
        end

        it "preserves the body content and strips the marker" do
          expect(subject).to include("Body content for #{type}.")
          expect(subject).not_to include("[#{described_class::TAG_NAME}: #{type}]")
        end
      end
    end

    context "when the type is unknown" do
      let(:original_content) do
        <<-HTML
          <table>
            <tr><td>[#{described_class::TAG_NAME}: nonsense]</td></tr>
            <tr><td>Authored Header</td></tr>
            <tr><td>Body text</td></tr>
          </table>
        HTML
      end

      it "falls back to the authored label without a type modifier" do
        expect(subject).to include("Authored Header")
        expect(subject).not_to include("o-ld-callout--nonsense")
      end
    end
  end
end
