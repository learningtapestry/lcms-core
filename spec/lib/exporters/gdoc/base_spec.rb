# frozen_string_literal: true

require "rails_helper"

describe Exporters::Gdoc::Base do
  describe ".file_id_from" do
    it "is the inverse of .url_for" do
      expect(described_class.file_id_from(described_class.url_for("ABC123"))).to eq("ABC123")
    end

    {
      "https://drive.google.com/open?id=ABC123" => "ABC123",
      "https://drive.google.com/open?id=ABC123&foo=bar" => "ABC123",
      "https://drive.google.com/open?id=ABC123#heading=h.x" => "ABC123",
      "https://docs.google.com/document/d/XYZ789/edit" => "XYZ789",
      "https://drive.google.com/file/d/QQQ000/view?usp=sharing" => "QQQ000",
      "https://docs.google.com/document/d/QRY111?usp=sharing" => "QRY111"
    }.each do |url, expected_id|
      it "extracts #{expected_id} from #{url}" do
        expect(described_class.file_id_from(url)).to eq(expected_id)
      end
    end

    it "returns nil for blank input" do
      expect(described_class.file_id_from(nil)).to be_nil
      expect(described_class.file_id_from("")).to be_nil
    end

    it "returns nil for a URL with no recognizable id" do
      expect(described_class.file_id_from("https://example.com/no-id-here")).to be_nil
    end
  end

  describe "#post_processing" do
    it "reports a missing template at once instead of retrying" do
      document = double("UnitPresenter")
      allow(document).to receive(:gdoc_template_id).and_raise(KeyError, "GOOGLE_APPLICATION_TEMPLATE_BUNDLE is not set")
      exporter = described_class.allocate
      allow(exporter).to receive(:document).and_return(document)
      allow(Retriable).to receive(:retriable)

      expect { exporter.send(:post_processing) }.to raise_error(KeyError, /not set/)
      expect(Retriable).not_to have_received(:retriable)
    end
  end
end
