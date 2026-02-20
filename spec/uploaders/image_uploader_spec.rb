# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImageUploader do
  describe ".delete_by_url" do
    context "when url is blank" do
      it "does nothing for nil" do
        expect { described_class.delete_by_url(nil) }.not_to raise_error
      end

      it "does nothing for empty string" do
        expect { described_class.delete_by_url("") }.not_to raise_error
      end
    end

    context "with a local file" do
      let(:url) { "/uploads/settings/image.png" }
      let(:path) { Rails.root.join("public", "uploads/settings/image.png") }

      before do
        FileUtils.mkdir_p(path.dirname)
        FileUtils.touch(path)
      end

      after { FileUtils.rm_f(path) }

      it "deletes the file" do
        described_class.delete_by_url(url)

        expect(File.exist?(path)).to be false
      end
    end

    context "with a local file that does not exist" do
      it "does not raise" do
        expect { described_class.delete_by_url("/uploads/settings/nonexistent.png") }.not_to raise_error
      end
    end

    context "with an S3 URL" do
      let(:url) { "https://bucket.s3.amazonaws.com/uploads/settings/image.png" }

      before { allow(S3Service).to receive(:delete_object) }

      it "calls S3Service.delete_object with the correct key" do
        described_class.delete_by_url(url)

        expect(S3Service).to have_received(:delete_object).with("uploads/settings/image.png")
      end
    end

    context "with an S3 URL outside allowed prefix" do
      let(:url) { "https://bucket.s3.amazonaws.com/other/path/image.png" }

      before { allow(S3Service).to receive(:delete_object) }

      it "does not call S3Service.delete_object" do
        described_class.delete_by_url(url)

        expect(S3Service).not_to have_received(:delete_object)
      end
    end

    context "when an error occurs" do
      let(:url) { "/uploads/settings/image.png" }

      before do
        allow(described_class).to receive(:delete_local).and_raise(StandardError, "Something went wrong")
        allow(Rails.logger).to receive(:warn)
      end

      it "logs a warning and does not raise" do
        expect { described_class.delete_by_url(url) }.not_to raise_error
        expect(Rails.logger).to have_received(:warn).with(/Failed to delete old image/)
      end
    end
  end
end
