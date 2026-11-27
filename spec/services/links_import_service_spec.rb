# frozen_string_literal: true

require "rails_helper"

describe LinksImportService do
  let(:csv) do
    <<~CSV
      URL ID,URL,Link Text
      NASA-01,https://www.nasa.gov/,NASA website
      noaa,https://www.noaa.gov/,
      ,,
    CSV
  end

  before { allow(ImportService).to receive(:call).and_return(csv) }

  it "replaces the links with the sheet's rows, skipping blank rows" do
    create(:link, identifier: "stale")

    expect(described_class.call("https://docs.google.com/spreadsheets/d/x")).to eq 2
    expect(Link.pluck(:identifier)).to contain_exactly("nasa-01", "noaa")
    expect(Link.find_by_identifier("nasa-01")).to have_attributes(url: "https://www.nasa.gov/", text: "NASA website")
    expect(Link.find_by_identifier("noaa").text).to be_nil
  end

  it "re-imports ids already in the table" do
    create(:link, identifier: "noaa", url: "https://old.example.com/")

    expect(described_class.call("x")).to eq 2
    expect(Link.find_by_identifier("noaa").url).to eq "https://www.noaa.gov/"
  end

  context "with an id repeated in the sheet" do
    let(:csv) { "URL ID,URL\nnoaa,https://x.com/\nNOAA,https://y.com/\n" }

    it "names both rows and imports nothing" do
      expect { described_class.call("x") }.to raise_error(LinksImportService::ImportError, /Row 3 \(NOAA\): Identifier repeats row 2/)
      expect(Link.count).to eq 0
    end
  end

  context "without the required columns" do
    let(:csv) { "Name,Text\nx,y\n" }

    it "raises and keeps the current links" do
      create(:link, identifier: "kept")

      expect { described_class.call("x") }.to raise_error(LinksImportService::ImportError, /urlid and url columns/)
      expect(Link.pluck(:identifier)).to eq ["kept"]
    end
  end

  context "with an invalid row" do
    let(:csv) { "URL ID,URL\nok,https://x.com/\nbad,ftp://x.com/file\n" }

    it "names the row and imports nothing" do
      expect { described_class.call("x") }.to raise_error(LinksImportService::ImportError, /Row 3 \(bad\)/)
      expect(Link.count).to eq 0
    end
  end
end
