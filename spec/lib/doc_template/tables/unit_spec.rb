# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tables::Unit do
  let(:table) { described_class.new }

  describe "#parse" do
    let(:html) { HtmlSanitizer.sanitize(data) }
    let(:fragment) { Nokogiri::HTML.fragment(html) }

    subject(:parsed_table) { table.parse(fragment) }

    context "with unit metadata and linked materials" do
      let!(:material1) { create(:material, identifier: "mat-1") }
      let!(:material2) { create(:material, identifier: "mat-2") }
      let(:data) { file_fixture("tables/unit-metadata.html").read }

      include_examples "removes metadata table"

      it "extracts raw metadata values" do
        expect(parsed_table.data).to include(
          "subject" => "math",
          "grade" => "6",
          "course" => "Algebra",
          "unit-id" => "m6u1a",
          "unit-title" => "Expressions and Equations",
          "unit-title-spanish" => "Expresiones y ecuaciones",
          "unit-topic" => "Variable relationships",
          "unit-topic-spanish" => "Relaciones entre variables",
          "copyright" => "Learning Tapestry",
          "license" => "CC BY-NC",
          "unit-materials" => "MAT-1, MAT-2"
        )
      end

      it "downcases unit-id for stable cross-references" do
        expect(parsed_table.data["unit-id"]).to eq("m6u1a")
      end

      it "preserves html fields" do
        expect(parsed_table.data["description"]).to include("<p>")
        expect(parsed_table.data["acknowledgements"]).to include("<p>")
      end

      it "resolves unit materials to material ids" do
        expect(parsed_table.data["material_ids"]).to eq([material1.id, material2.id])
      end

      it "does not add validation errors for valid metadata" do
        expect(parsed_table.errors).to be_empty
      end
    end

    context "with invalid metadata" do
      let(:data) do
        <<~HTML
          <html>
            <body>
              <table>
                <tbody>
                  <tr>
                    <td colspan="2">unit-metadata</td>
                  </tr>
                  <tr>
                    <td>subject</td>
                    <td>math</td>
                  </tr>
                  <tr>
                    <td>grade</td>
                    <td>grade six</td>
                  </tr>
                  <tr>
                    <td>unit-id</td>
                    <td>M6-U1</td>
                  </tr>
                  <tr>
                    <td>unit-materials</td>
                    <td>MISSING-1</td>
                  </tr>
                </tbody>
              </table>
            </body>
          </html>
        HTML
      end

      it "collects validation errors" do
        expect(parsed_table.errors).to include(
          "unit-title is required",
          "unit-topic is required",
          "description is required",
          "Invalid grade: 'grade six' (must be numeric)",
          "Invalid unit-id: 'm6-u1' (must be alphanumeric)",
          "Unknown unit-materials identifier: 'MISSING-1'"
        )
      end

      it "does not emit duplicate errors for a repeated missing identifier" do
        html = <<~HTML
          <html><body>
            <table>
              <tbody>
                <tr><td colspan="2">unit-metadata</td></tr>
                <tr><td>subject</td><td>math</td></tr>
                <tr><td>grade</td><td>6</td></tr>
                <tr><td>unit-id</td><td>U1</td></tr>
                <tr><td>unit-title</td><td>T</td></tr>
                <tr><td>unit-topic</td><td>X</td></tr>
                <tr><td>description</td><td>D</td></tr>
                <tr><td>unit-materials</td><td>MISSING-1, MISSING-1</td></tr>
              </tbody>
            </table>
          </body></html>
        HTML
        fragment = Nokogiri::HTML.fragment(HtmlSanitizer.sanitize(html))
        errors = described_class.new.parse(fragment).errors
        expect(errors.count { |e| e.include?("MISSING-1") }).to eq(1)
      end
    end
  end
end
