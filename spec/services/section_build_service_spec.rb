# frozen_string_literal: true

require "rails_helper"

describe SectionBuildService do
  describe "#build_for" do
    let(:credentials) { double("credentials") }
    let(:url) { "https://docs.google.com/document/d/section-file-id/edit" }
    let(:canonical_url) { "https://docs.google.com/document/d/section-file-id" }
    let(:html) { file_fixture("tables/section-metadata-resource.html").read }
    let(:file) { double("file", name: "Section Metadata Source") }
    let(:downloader) do
      double(
        "downloader",
        content: html,
        file:,
        file_id: "section-file-id"
      )
    end

    before do
      create(:material, identifier: "mat-1")
      create(:material, identifier: "mat-2")
      allow(::Lt::Lcms::Lesson::Downloader::Gdoc).to receive(:new).and_return(downloader)
      allow(downloader).to receive(:download).and_return(downloader)
    end

    subject(:resource) { described_class.new(credentials).build_for(url) }

    it "builds a section resource from the metadata table" do
      expect(resource).to be_a(Resource)
      expect(resource).to be_section
      expect(resource.metadata["section_title"]).to eq("Expressions with Variables")
    end

    it "stores source metadata on the resource links" do
      expect(resource.links.dig("source", "gdoc", "file_id")).to eq("section-file-id")
      expect(resource.links.dig("source", "gdoc", "url")).to eq(canonical_url)
    end

    context "when the document has no section-metadata table" do
      let(:html) { "<html><body><p>nothing here</p></body></html>" }

      it "raises a descriptive error" do
        expect { resource }.to raise_error(RuntimeError, /No section metadata present/)
      end
    end

    context "with invalid section metadata" do
      let(:html) do
        <<~HTML
          <html>
            <body>
              <table>
                <tbody>
                  <tr><td colspan="2">section-metadata</td></tr>
                  <tr><td>subject</td><td>math</td></tr>
                  <tr><td>grade</td><td>six</td></tr>
                </tbody>
              </table>
            </body>
          </html>
        HTML
      end

      it "raises with validation details" do
        expect { resource }.to raise_error(RuntimeError, /Invalid section metadata/)
      end
    end
  end
end
