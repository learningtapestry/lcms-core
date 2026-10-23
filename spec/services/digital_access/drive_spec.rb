# frozen_string_literal: true

require "rails_helper"

describe DigitalAccess::Drive do
  let(:service) { instance_double(Google::Apis::DriveV3::DriveService) }
  let(:files) do
    {
      "src" => [file("s1", "Field Guide.pdf", "2026-10-01"), file("s2", "Slides", "2026-10-05"), folder("sub", "Unit 1")],
      "out" => [
        file("c1", "Field Guide.pdf", nil, { "lcmsSourceId" => "s1", "lcmsSourceModified" => "2026-10-01" }),
        file("c2", "Slides", nil, { "lcmsSourceId" => "s2", "lcmsSourceModified" => "2026-09-01" }),
        file("c3", "Old.pdf", nil, { "lcmsSourceId" => "gone", "lcmsSourceModified" => "2026-01-01" }),
        file("lesson", "Lesson 1 (LCMS document)", nil)
      ]
    }
  end

  def file(id, name, modified, app_properties = nil)
    Google::Apis::DriveV3::File.new(id:, name:, mime_type: "application/pdf", modified_time: modified,
                                    app_properties:)
  end

  def folder(id, name)
    Google::Apis::DriveV3::File.new(id:, name:, mime_type: DigitalAccess::Drive::FOLDER_MIME)
  end

  subject(:drive) { described_class.new(service) }

  before do
    allow(service).to receive(:list_files) do |q:, **|
      Google::Apis::DriveV3::FileList.new(files: files.fetch(q[/"([^"]+)" in parents/, 1], []))
    end
    allow(service).to receive(:delete_file)
    allow(service).to receive(:copy_file)
  end

  describe ".folder_id_for" do
    it "reads a folder link, an open?id= link or a bare id" do
      expect(described_class.folder_id_for("https://drive.google.com/drive/folders/1AbC-dEf_ghIJ?usp=sharing")).to eq "1AbC-dEf_ghIJ"
      expect(described_class.folder_id_for("https://drive.google.com/open?id=1AbCdEfGhIJ")).to eq "1AbCdEfGhIJ"
      expect(described_class.folder_id_for("1AbCdEfGhIJkl")).to eq "1AbCdEfGhIJkl"
      expect(described_class.folder_id_for("")).to be_nil
    end
  end

  describe "#sync_copies" do
    it "re-copies changed files, removes copies of deleted files and leaves everything else alone" do
      drive.sync_copies("src", "out")

      expect(service).to have_received(:delete_file).with("c2", supports_all_drives: true)
      expect(service).to have_received(:delete_file).with("c3", supports_all_drives: true)
      expect(service).not_to have_received(:delete_file).with("c1", anything)
      expect(service).not_to have_received(:delete_file).with("lesson", anything)
      expect(service).to have_received(:copy_file).once
      expect(service).to have_received(:copy_file).with("s2", have_attributes(
        name: "Slides", parents: ["out"],
        app_properties: { "lcmsSourceId" => "s2", "lcmsSourceModified" => "2026-10-05" }
      ), supports_all_drives: true)
    end

    it "removes every copy when there is no source folder" do
      drive.sync_copies(nil, "out")

      expect(service).to have_received(:delete_file).exactly(3).times
      expect(service).not_to have_received(:copy_file)
    end
  end

  describe "#download" do
    let(:item) { ->(name, mime_type) { DigitalAccess::Drive::Item.new(id: "f1", name:, mime_type:) } }

    it "downloads a file as it is" do
      allow(service).to receive(:get_file) { |_id, download_dest:, **| download_dest.write("%PDF") }

      expect(drive.download(item.("Guide.pdf", "application/pdf"))).to eq ["Guide.pdf", "%PDF"]
      expect(service).to have_received(:get_file).with("f1", download_dest: anything, supports_all_drives: true)
    end

    it "exports Google Docs, Sheets and Slides to their Office format" do
      allow(service).to receive(:export_file) { |_id, _mime, download_dest:| download_dest.write("PK") }

      expect(drive.download(item.("Unit Slides", "application/vnd.google-apps.presentation"))).to eq ["Unit Slides.pptx", "PK"]
      expect(drive.download(item.("Notes.docx", "application/vnd.google-apps.document"))).to eq ["Notes.docx", "PK"]
      expect(service).to have_received(:export_file)
        .with("f1", "application/vnd.openxmlformats-officedocument.presentationml.presentation", download_dest: anything)
    end

    it "skips what Drive cannot hand over" do
      expect(drive.download(item.("Survey", "application/vnd.google-apps.form"))).to be_nil
    end
  end

  describe "#folder" do
    it "returns the existing folder or creates it" do
      allow(service).to receive(:create_file).and_return(Google::Apis::DriveV3::File.new(id: "new"))

      expect(drive.folder("Unit 1", "src")).to eq "sub"
      expect(drive.folder("Unit 2", "src")).to eq "new"
      expect(service).to have_received(:create_file).with(
        have_attributes(name: "Unit 2", parents: ["src"], mime_type: DigitalAccess::Drive::FOLDER_MIME),
        fields: "id", supports_all_drives: true
      )
    end
  end
end
