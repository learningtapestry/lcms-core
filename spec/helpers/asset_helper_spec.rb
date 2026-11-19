# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssetHelper do
  describe ".base64_encoded" do
    let(:redis) { instance_double(Redis, get: nil, set: true) }

    before do
      allow(described_class).to receive_messages(redis:, encode: "data:text/css;base64,NEW")
    end

    it "does not cache outside production-like environments" do
      expect(described_class.base64_encoded("pdf.css", cache: true)).to eq "data:text/css;base64,NEW"
      expect(redis).not_to have_received(:get)
      expect(redis).not_to have_received(:set)
    end

    context "with precompiled assets" do
      before do
        allow(Rails.env).to receive_messages(development?: false, test?: false, qa?: false)
        manifest = instance_double(Sprockets::Manifest, assets: { "pdf.css" => "pdf-abc123.css" })
        allow(Rails.application).to receive(:assets_manifest).and_return(manifest)
      end

      it "caches under the digested name, so a changed asset is not served from the cache" do
        described_class.base64_encoded("pdf.css", cache: true)

        expect(redis).to have_received(:get).with("#{AssetHelper::REDIS_PREFIX}pdf-abc123.css")
        expect(redis).to have_received(:set).with("#{AssetHelper::REDIS_PREFIX}pdf-abc123.css", anything, ex: 1.day.to_i)
      end

      it "returns the cached copy when there is one" do
        allow(redis).to receive(:get).and_return("data:text/css;base64,OLD")

        expect(described_class.base64_encoded("pdf.css", cache: true)).to eq "data:text/css;base64,OLD"
      end
    end
  end

  describe ".inline_data_uri" do
    it "returns nil for a blank url" do
      expect(described_class.inline_data_uri("")).to be_nil
    end

    context "when the URL has no recognizable extension" do
      let(:url) { "https://cdn.example.com/logo" }

      it "derives the MIME from the server Content-Type" do
        allow(described_class).to receive(:fetch_remote).with(url).and_return(["binarydata", "image/png"])

        expect(described_class.inline_data_uri(url)).to start_with("data:image/png;base64,")
      end

      it "falls back to application/octet-stream when no Content-Type is available" do
        allow(described_class).to receive(:fetch_remote).with(url).and_return(["binarydata", nil])

        expect(described_class.inline_data_uri(url)).to start_with("data:application/octet-stream;base64,")
      end

      it "strips parameters from the Content-Type" do
        allow(described_class).to receive(:fetch_remote).with(url).and_return(["binarydata", "image/jpeg; charset=binary"])

        expect(described_class.inline_data_uri(url)).to start_with("data:image/jpeg;base64,")
      end
    end

    it "prefers the URL extension over the Content-Type" do
      url = "https://cdn.example.com/logo.png"
      allow(described_class).to receive(:fetch_remote).with(url).and_return(["binarydata", "application/octet-stream"])

      expect(described_class.inline_data_uri(url)).to start_with("data:image/png;base64,")
    end

    it "detects SVG by content sniffing regardless of Content-Type" do
      url = "https://cdn.example.com/logo"
      allow(described_class).to receive(:fetch_remote).with(url).and_return(["<svg xmlns='...'></svg>", "text/plain"])

      expect(described_class.inline_data_uri(url)).to start_with("data:image/svg+xml;base64,")
    end
  end

  # open-uri calls this with the running transfer total, including for chunked
  # responses that carry no Content-Length (where content_length_proc never
  # fires), so the cap holds mid-stream rather than after the whole body landed.
  describe "the fetch size guard" do
    subject(:guard) { described_class.send(:fetch_limit_guard) }

    it "aborts once the transfer passes the limit" do
      expect { guard.call(described_class::DATA_URI_FETCH_LIMIT + 1) }
        .to raise_error(/exceeds/)
    end

    it "allows a transfer at the limit" do
      expect { guard.call(described_class::DATA_URI_FETCH_LIMIT) }.not_to raise_error
    end

    it "allows an ordinary asset" do
      expect { guard.call(120.kilobytes) }.not_to raise_error
    end
  end
end
