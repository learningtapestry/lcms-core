# frozen_string_literal: true

require "rails_helper"

describe UnitBuildService do
  describe "#build_for" do
    let(:credentials) { double("credentials") }
    let(:url) { "https://docs.google.com/document/d/unit-file-id/edit" }
    let(:canonical_url) { "https://docs.google.com/document/d/unit-file-id" }
    let(:html) { file_fixture("tables/unit-metadata.html").read }
    let(:file) { double("file", name: "Unit Metadata Source") }
    let(:downloader) do
      double(
        "downloader",
        content: html,
        file:,
        file_id: "unit-file-id"
      )
    end

    before do
      create(:material, identifier: "mat-1")
      create(:material, identifier: "mat-2")
      allow(::Lt::Lcms::Lesson::Downloader::Gdoc).to receive(:new).and_return(downloader)
      allow(downloader).to receive(:download).and_return(downloader)
    end

    subject(:resource) { described_class.new(credentials).build_for(url) }

    it "builds a unit resource from the metadata table" do
      expect(resource).to be_a(Resource)
      expect(resource).to be_unit
      expect(resource.metadata["unit_title"]).to eq("Expressions and Equations")
    end

    it "stores source metadata on the resource links" do
      expect(resource.links.dig("source", "gdoc", "file_id")).to eq("unit-file-id")
      expect(resource.links.dig("source", "gdoc", "url")).to eq(canonical_url)
    end

    context "with invalid unit metadata" do
      let(:html) do
        <<~HTML
          <html>
            <body>
              <table>
                <tbody>
                  <tr><td colspan="2">unit-metadata</td></tr>
                  <tr><td>subject</td><td>math</td></tr>
                  <tr><td>grade</td><td>six</td></tr>
                </tbody>
              </table>
            </body>
          </html>
        HTML
      end

      it "raises with validation details" do
        expect { resource }.to raise_error(RuntimeError, /Invalid unit metadata/)
      end
    end

    context "when the document has no unit-metadata table" do
      let(:html) { "<html><body><p>nothing here</p></body></html>" }

      it "raises a descriptive error" do
        expect { resource }.to raise_error(RuntimeError, /No unit metadata present/)
      end
    end
  end
end
