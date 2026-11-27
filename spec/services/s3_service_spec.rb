# frozen_string_literal: true

require "rails_helper"

describe S3Service do
  describe ".upload" do
    let(:data) { StringIO.new("data to be uploaded") }
    let(:full_options) { options.merge(body: data, cache_control: "public, max-age=0, must-revalidate") }
    let(:key) { "path/to/file" }
    let(:object) do
      params = {
        put: "true",
        public_url: url
      }
      double(Aws::S3::Resource, **params)
    end
    let(:options) { { content_type: "image/png" } }
    let(:url) { Faker::Internet.url }

    before { allow(described_class).to receive(:create_object).with(key).and_return(object) }

    subject { described_class.upload(key, data, options) }

    it "uploads data with passed params" do
      expect(object).to receive(:put).with(full_options)
      subject
    end

    it "returns URL of the uploaded object"

    context "when S3 is blocked" do
      let(:key) { "spec-s3-service/#{SecureRandom.hex(4)}/file.pdf" }

      before { stub_const("AWS_S3_BLOCK", true) }

      after { FileUtils.rm_rf(Rails.root.join("s3", "spec-s3-service")) }

      it "writes a string to the local s3 directory and returns its path" do
        path = described_class.upload(key, "pdf bytes")

        expect(path).to eq Rails.root.join("s3", key).to_s
        expect(File.binread(path)).to eq "pdf bytes"
      end

      it "writes the whole content of an IO, even one already read" do
        data.read

        expect(File.binread(described_class.upload(key, data))).to eq "data to be uploaded"
      end
    end
  end
end
