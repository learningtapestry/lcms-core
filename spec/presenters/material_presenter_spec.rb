# frozen_string_literal: true

require "rails_helper"

describe MaterialPresenter do
  let(:material) do
    create(:material, metadata: {
      "attribution" => "CC BY 4.0",
      "material_id" => "TEST.MAT.001",
      "material_title" => "Student Worksheet",
      "material_type" => "handout",
      "language" => "English",
      "orientation" => "portrait"
    })
  end
  let(:presenter) { described_class.new(material) }

  describe "#gdoc_footer" do
    context "when attribution is present" do
      it "returns 2D array with attribution placeholder and value" do
        result = presenter.gdoc_footer

        expect(result).to eq([
          ["{attribution}"],
          ["CC BY 4.0"]
        ])
      end
    end

    context "when attribution is blank" do
      let(:material) do
        create(:material, metadata: {
          "attribution" => "",
          "material_id" => "TEST.MAT.001",
          "material_title" => "Student Worksheet",
          "material_type" => "handout",
          "language" => "English",
          "orientation" => "portrait"
        })
      end

      it "returns default attribution text" do
        result = presenter.gdoc_footer

        expect(result).to eq([
          ["{attribution}"],
          ["Copyright attribution here"]
        ])
      end
    end

    context "when attribution is nil" do
      let(:material) do
        create(:material, metadata: {
          "material_id" => "TEST.MAT.001",
          "material_title" => "Student Worksheet",
          "material_type" => "handout",
          "language" => "English",
          "orientation" => "portrait"
        })
      end

      it "returns default attribution text" do
        result = presenter.gdoc_footer

        expect(result).to eq([
          ["{attribution}"],
          ["Copyright attribution here"]
        ])
      end
    end
  end

  describe "#gdoc_header" do
    context "when material_title is present in metadata" do
      it "returns 2D array with title placeholder and value" do
        result = presenter.gdoc_header

        expect(result).to eq([
          ["{title}"],
          ["Student Worksheet"]
        ])
      end
    end
  end

  describe "#orientation" do
    context "when orientation is set in metadata" do
      let(:material) do
        create(:material, metadata: {
          "material_id" => "TEST.MAT.001",
          "material_title" => "Student Worksheet",
          "material_type" => "handout",
          "language" => "English",
          "orientation" => "landscape"
        })
      end

      it "returns orientation from metadata" do
        # RenderOptions normalizes orientation to a symbol in ALLOWED_ORIENTATION;
        # the presenter delegates straight to render_options.orientation.
        expect(presenter.orientation).to eq(:landscape)
      end
    end

    context "when orientation is set to 'l' in metadata" do
      let(:material) do
        create(:material, metadata: {
          "material_id" => "TEST.MAT.001",
          "material_title" => "Student Worksheet",
          "material_type" => "handout",
          "language" => "English",
          "orientation" => "l"
        })
      end

      it "normalizes to landscape" do
        expect(presenter.orientation).to eq(:landscape)
      end
    end

    context "when orientation is set to 'p' in metadata" do
      let(:material) do
        create(:material, metadata: {
          "material_id" => "TEST.MAT.001",
          "material_title" => "Student Worksheet",
          "material_type" => "handout",
          "language" => "English",
          "orientation" => "p"
        })
      end

      it "normalizes to portrait" do
        expect(presenter.orientation).to eq(:portrait)
      end
    end
  end

  describe "#external_assets" do
    context "when the material has external-asset URLs" do
      let(:material) do
        create(:material, metadata: {
          "material_id" => "TEST.MAT.001",
          "material_title" => "Lesson 7 Slides",
          "material_type" => "slides",
          "language" => "English",
          "external_assets" => {
            "pdf" => "",
            "slides" => "https://docs.google.com/presentation/d/abc/edit",
            "video" => "https://youtu.be/xyz",
            "webpage" => ""
          }
        })
      end

      it "returns only populated links in EXTERNAL_ASSETS order with labels" do
        expect(presenter.external_assets).to eq([
          { label: "Slides", url: "https://docs.google.com/presentation/d/abc/edit" },
          { label: "Video", url: "https://youtu.be/xyz" }
        ])
      end
    end

    context "when the material has no external assets" do
      it "returns an empty array" do
        expect(presenter.external_assets).to eq([])
      end
    end

    # These URLs are authored in a Google Doc and persisted even when
    # ExternalAssetRepresentation#validate_urls objects (MaterialBuildService
    # calls #update! regardless of @errors), then emitted as hrefs on the public
    # material page. #safe_asset_url? is the only thing standing between an
    # authored value and stored XSS, so it is tested as a filter, not a helper.
    context "when an external-asset URL carries an injection scheme" do
      def assets_for(url)
        material.update!(metadata: material.metadata.merge("external_assets" => { "webpage" => url }))
        described_class.new(material.reload).external_assets
      end

      %w(javascript:alert(1) vbscript:alert(1) data:text/html,<script>alert(1)</script>).each do |url|
        it "drops #{url.split(':').first}:" do
          expect(assets_for(url)).to eq([])
        end
      end

      # Browsers strip tab/CR/LF/NUL inside a scheme and navigate as though they
      # were never there, so these are live javascript: URLs. They do not match a
      # scheme pattern, so a naive check reads them as schemeless — i.e. relative
      # — and lets them through.
      [
        ["tab", "java\tscript:alert(1)"],
        ["newline", "java\nscript:alert(1)"],
        ["carriage return", "JAVA\rSCRIPT:alert(1)"]
        # No NUL case: Postgres rejects \u0000 inside a jsonb string, so such a
        # value cannot reach this code path through stored metadata at all.
        # #safe_asset_url? strips it regardless.
      ].each do |name, url|
        it "drops a scheme split by a #{name}" do
          expect(assets_for(url)).to eq([])
        end
      end
    end

    context "when an external-asset URL is legitimate" do
      def urls_for(url)
        material.update!(metadata: material.metadata.merge("external_assets" => { "webpage" => url }))
        described_class.new(material.reload).external_assets.map { _1[:url] }
      end

      %w(https://ok.test/a.pdf http://ok.test/a.pdf mailto:teacher@ok.test /relative/a.pdf relative/a.pdf).each do |url|
        it "keeps #{url}" do
          expect(urls_for(url)).to eq([url])
        end
      end
    end
  end

  describe "integration with Google::ScriptService" do
    it "provides compatible format for ScriptService#parameters" do
      footer = presenter.gdoc_footer
      header = presenter.gdoc_header

      expect(footer).to be_an(Array)
      expect(footer.size).to eq(2)
      expect(footer.all? { |row| row.is_a?(Array) }).to be true

      expect(header).to be_an(Array)
      expect(header.size).to eq(2)
      expect(header.all? { |row| row.is_a?(Array) }).to be true
    end
  end
end
