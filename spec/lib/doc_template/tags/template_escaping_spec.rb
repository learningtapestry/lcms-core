# frozen_string_literal: true

require "rails_helper"

# BaseTag#parse_template renders with `escape: true` (Erubi), so every `<%= %>`
# is HTML-escaped unless the template opts out with `raw` / `.html_safe`.
#
# Values that reach a template via #parse_nested arrive html_safe and need no
# opt-out. Values a tag builds by hand — String interpolation, #to_html, #join,
# #inner_html — are plain Strings, and escaping them prints their markup as
# literal text in the exported lesson.
#
# These tags each pass a hand-built String, and none of them had a spec when the
# escaping default was introduced, which is how all six templates shipped
# double-escaped. The assertion is deliberately about the rendered markup rather
# than the flag, since that is what the reader of a PDF sees.
describe "tag template escaping" do
  # Any escaped tag delimiter means the markup is being printed instead of
  # rendered, whatever produced it.
  matcher :render_markup do
    match { |output| !output.include?("&lt;") && !output.include?("&gt;") }
    failure_message { |output| "expected rendered markup, got escaped text:\n#{output}" }
  end

  def render(klass, template, params)
    klass.new.send(:parse_template, params, template)
  end

  describe DocTemplate::Tags::ExpandTag do
    # #fetch_content returns `nodes.map(&:to_html).join` — a plain String.
    let(:params) { { subject: "ela", content: "<p>visible</p>", content_hidden: "<p>hidden</p>" } }

    it "renders the visible and hidden content as markup" do
      output = render(described_class, "expand.html.erb", params)

      expect(output).to render_markup
      expect(output).to include("<p>visible</p>", "<p>hidden</p>")
    end

    it "renders both in the gdoc template" do
      output = render(described_class, "gdoc/expand.html.erb", params)

      expect(output).to render_markup
      expect(output).to include("<p>visible</p>", "<p>hidden</p>")
    end

    it "still escapes the subject, which is a computed literal" do
      output = render(described_class, "expand.html.erb", params.merge(subject: "<script>"))

      expect(output).not_to include("<script>")
    end
  end

  describe DocTemplate::Tags::IndentTag do
    # #parsed_content ends in "#{prepend_html}#{html}" — interpolation drops the
    # html_safe flag parse_nested put on `html`.
    let(:params) { { content: "<br><p>indented</p>" } }

    it "renders the content as markup" do
      output = render(described_class, "indent.html.erb", params)

      expect(output).to render_markup
      expect(output).to include("<br><p>indented</p>")
    end

    it "renders the content as markup in the gdoc template" do
      output = render(described_class, "gdoc/indent.html.erb", params)

      expect(output).to render_markup
      expect(output).to include("<br><p>indented</p>")
    end
  end

  describe DocTemplate::Tags::PositionTag do
    # #parse_table passes the cell's #inner_html.
    it "renders the content as markup" do
      output = render(described_class, "position.html.erb", { content: %(<img src="x.png">), position: "left" })

      expect(output).to render_markup
      expect(output).to include(%(<img src="x.png">))
    end
  end

  describe DocTemplate::Tags::HeadingTag do
    # #parse builds `heading` as "<h3>#{…}</h3>"; `content` comes from
    # parse_nested and is already html_safe.
    let(:params) { { content: "<p>body</p>".html_safe, heading: "<h3>Rubric: Test</h3>", tag: "rubric" } }

    it "renders the heading as an element, not as text" do
      output = render(described_class, "heading.html.erb", params)

      expect(output).to render_markup
      expect(output).to include("<h3>Rubric: Test</h3>")
    end

    it "renders the line break KeyTag and ThTag put inside the heading" do
      output = render(described_class, "heading.html.erb", params.merge(heading: "Answer Key<br/>(For Teacher Reference)"))

      expect(output).to render_markup
      expect(output).to include("<br/>")
    end

    it "still escapes the tag name, which is a computed literal" do
      output = render(described_class, "heading.html.erb", params.merge(tag: %("><script>)))

      expect(output).not_to include("<script>")
    end
  end

  describe DocTemplate::Tags::SectionTag do
    # A stand-in rather than a real Objects::Sections::Section: the template also
    # reads `section[:use_color]`, which no object in this codebase declares —
    # see the "raises for undeclared attributes" example in sections_spec.rb.
    # That is a separate, pre-existing problem; this example is only about the
    # metacognition markup.
    let(:section) do
      Struct.new(:anchor, :title, :time) do
        def [](_key) = nil
      end.new("opening", "Opening", 10)
    end

    # metacog is section.metacognition.original_content — raw source HTML.
    it "renders metacognition as markup in the gdoc template" do
      output = render(described_class, "gdoc/section.html.erb",
                      { section:, metacog: "<p>think</p>", placeholder: "{{x}}", content: "" })

      expect(output).to include("<p>think</p>")
    end
  end
end
