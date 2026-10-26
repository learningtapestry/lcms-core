# frozen_string_literal: true

require "rails_helper"

describe ImagesImportService do
  let(:csv) do
    <<~CSV
      Image ID,File,Caption,Credit,Alt Text
      1234BW20P,https://cdn.example.com/a.jpg,Image of a mountain scene.,Used with permission.,A lake
      map-01,images/k/School Map.png,,,
      ,,,,
    CSV
  end

  before do
    allow(ImportService).to receive(:call).and_return(csv)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("AWS_S3_BUCKET_NAME", nil).and_return("lcms-bucket")
    allow(ENV).to receive(:fetch).with("AWS_REGION", nil).and_return("us-west-2")
  end

  it "replaces the images with the sheet's rows, skipping blank rows" do
    create(:image, identifier: "stale")

    expect(described_class.call("https://docs.google.com/spreadsheets/d/x")).to eq 2
    expect(Image.pluck(:identifier)).to contain_exactly("1234bw20p", "map-01")
    expect(Image.find_by_identifier("1234bw20p")).to have_attributes(
      file_url: "https://cdn.example.com/a.jpg", caption: "Image of a mountain scene.",
      credit: "Used with permission.", alt_text: "A lake"
    )
  end

  it "re-imports ids already in the table" do
    create(:image, identifier: "map-01")

    expect(described_class.call("x")).to eq 2
    expect(Image.find_by_identifier("map-01").file_url).to end_with "/images/k/School%20Map.png"
  end

  context "with an id repeated in the sheet" do
    let(:csv) { "Image ID,File\nmap-01,https://x.com/a.jpg\nMap-01,https://x.com/b.jpg\n" }

    it "names both rows and imports nothing" do
      expect { described_class.call("x") }.to raise_error(ImagesImportService::ImportError, /Row 3 \(Map-01\): Identifier repeats row 2/)
      expect(Image.count).to eq 0
    end
  end

  it "turns a bucket key into the bucket's URL" do
    described_class.call("x")

    expect(Image.find_by_identifier("map-01").file_url)
      .to eq "https://lcms-bucket.s3.us-west-2.amazonaws.com/images/k/School%20Map.png"
  end

  context "without the required columns" do
    let(:csv) { "Name,Caption\nx,y\n" }

    it "raises and keeps the current images" do
      create(:image, identifier: "kept")

      expect { described_class.call("x") }.to raise_error(ImagesImportService::ImportError, /imageid and file columns/)
      expect(Image.pluck(:identifier)).to eq ["kept"]
    end
  end

  context "with an invalid row" do
    let(:csv) { "Image ID,File,Caption\nok,https://x.com/a.jpg,\nbad,,Has no file\n" }

    it "names the row and imports nothing" do
      expect { described_class.call("x") }.to raise_error(ImagesImportService::ImportError, /Row 3 \(bad\)/)
      expect(Image.count).to eq 0
    end
  end
end
