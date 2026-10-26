# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssetHelper do
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
