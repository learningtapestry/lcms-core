# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tags::ActivityMetadataTypeTag do
  let(:rows) do
    {
      "activity-title" => "Title",
      "activity-time" => "5",
      "activity-label" => "required",
      "activity-type" => "discussion",
      "student-grouping" => "class",
      "activity-type-purpose" => "This is an example of an activity type purpose.",
      "activity-materials-class" => "Chart paper",
      "submission-required" => "Yes",
      "activity-description" => %(<p><span>In this activity, </span><span style="font-style:italic">lorem</span><span> ipsum.</span></p>)
    }
  end
  let(:html) do
    cells = rows.map { |key, value| %(<tr><td><p><span>#{key}</span></p></td><td>#{value.start_with?('<') ? value : "<p><span>#{value}</span></p>"}</td></tr>) }
    <<~HTML
      <html><body>
      <table><tr><td><p><span>lesson-metadata</span></p></td><td></td></tr>
      <tr><td><p><span>subject</span></p></td><td><p><span>science</span></p></td></tr>
      <tr><td><p><span>grade</span></p></td><td><p><span>k</span></p></td></tr></table>
      <table><tr><td><p><span>activity-metadata</span></p></td><td></td></tr>#{cells.join}</table>
      <p><span style="font-weight:700">Heading</span></p><ol><li><span>Step One</span></li></ol>
      </body></html>
    HTML
  end
  let(:template) { DocTemplate::Template.parse(html) }

  %w(default gdoc).each do |context_type|
    context "in the #{context_type} context" do
      # The activity renders as its own part behind a placeholder.
      subject(:output) do
        template.parts.find { it[:context_type].to_s == context_type && it[:part_type].to_s.start_with?("activity") }[:content]
      end

      it "renders the activity heading, metadata lines, description and content in spec order" do
        heading_at = output.index("Activity 1: Title (5 minutes) REQUIRED")
        order = ["This is an example of an activity type purpose.", "Materials: Chart paper",
                 "Submission Required", "Description: <span>In this activity", "Step One"].map { output.index(it) }

        expect(heading_at).to be_present
        expect(order).to all(be_present)
        expect([heading_at, *order]).to eq [heading_at, *order].sort
      end

      it "keeps the description's authored formatting after the label" do
        expect(output).to match(%r{<p>Description: <span>In this activity, </span><span style="font-style:italic">lorem</span>})
      end

      it "sets the content apart from the metadata lines with a blank line" do
        gap = context_type == "gdoc" ? %(<p class="o-ld-activity__spacer">) : %(<div class="o-ld-activity__content">)

        expect(output.rindex(gap)).to be < output.index("Heading")
        expect(output.rindex(gap)).to be > output.index("Description:")
      end

      it "renders tags authored in the metadata fields" do
        create(:link, identifier: "nasa-01", url: "https://www.nasa.gov/", text: "NASA")
        rows["activity-type-purpose"] = "Read about [url: nasa-01]."
        rows["activity-description"] = %(<p><span>Watch [url: nasa-01].</span></p>)

        expect(output).to match(%r{Read about <a href="https://www.nasa.gov/"[^>]*>NASA</a>\.})
        expect(output).to match(%r{Description: <span>Watch <a href="https://www.nasa.gov/"[^>]*>NASA</a>\.</span>})
      end

      it "omits the purpose and submission lines when not authored" do
        rows.delete("activity-type-purpose")
        rows["submission-required"] = "No"

        expect(output).not_to include("o-ld-activity__purpose", "Submission Required")
      end
    end
  end

  describe "#labeled_description" do
    let(:tag) { described_class.new }

    it "gives the label its own paragraph when the description opens with a list" do
      expect(tag.labeled_description("<ul><li>one</li></ul>")).to eq "<p>Description:</p><ul><li>one</li></ul>"
    end

    it "wraps a plain-text description" do
      expect(tag.labeled_description("In this activity")).to eq "<p>Description: In this activity</p>"
    end
  end
end
