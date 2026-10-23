# frozen_string_literal: true

require "rails_helper"

describe FullDownloadBundleJob do
  let(:job) { described_class.new }

  # A lesson or material whose nested PDF job stored `url` at `timestamp`
  # (nil url: no PDF).
  def pdf_record(id, filename, url = "https://s3.test/#{filename}", timestamp: 2_000, **attrs)
    links = url ? { "full_download" => { "pdf" => { "url" => url, "timestamp" => timestamp } } } : {}
    double("Presenter #{id}", id:, pdf_filename: filename, reload: double(links:), **attrs)
  end

  let(:shared_material) { pdf_record(13, "worksheet.pdf") }
  let(:unit_material) { pdf_record(11, "unit-material.pdf") }
  let(:section_material) { pdf_record(12, "section-material.pdf") }
  let(:lesson) { pdf_record(21, "lesson-1.pdf", lesson_materials: [shared_material]) }
  let(:lesson2) { pdf_record(22, "lesson-2.pdf", lesson_materials: [shared_material]) }
  let(:section) { instance_double(SectionPresenter, section_materials: [section_material], lessons: [lesson, lesson2]) }
  let(:unit) do
    double("UnitPresenter", unit_materials: [unit_material], sections: [section], links: {},
                            pdf_filename: "unit.pdf", bundle_folder: "bundles/full_download/k_u1")
  end
  let(:node) { DigitalAccess::Layout::Node }
  let(:course_node) do
    lesson_nodes = [node.new(record: lesson, name: "Lesson 1: Seeds", source_id: "lesson_src", children: []),
                    node.new(record: lesson2, name: "Lesson 2", source_id: nil, children: [])]
    section_node = node.new(record: section, name: "Section 1 / Plants", source_id: nil, children: lesson_nodes)
    unit_node = node.new(record: unit, name: "Unit 1", source_id: "unit_src", children: [section_node])
    node.new(record: nil, name: "Kindergarten Science", source_id: "root_src", children: [unit_node])
  end
  let(:layout) { instance_double(DigitalAccess::Layout, build: course_node) }
  let(:item) { ->(id, name, folder: false) { DigitalAccess::Drive::Item.new(id:, name:, folder:) } }
  let(:drive) { instance_double(DigitalAccess::Drive) }
  let(:settings) { { non_lcms_root_url: "https://drive.google.com/drive/folders/SRCROOT123", download_root_name: "OpenSciEd" } }

  before do
    job.instance_variable_set(:@unit, unit)
    job.instance_variable_set(:@options, { initial_job_id: "job_1", renderer: "grover" })
    allow(Settings).to receive(:get).and_call_original
    allow(Settings).to receive(:get).with(:bundles, include_defaults: true).and_return(settings)
    allow(Google::DriveService).to receive(:new).and_return(double(service: :raw_service))
    allow(DigitalAccess::Drive).to receive(:new).with(:raw_service).and_return(drive)
    allow(DigitalAccess::Layout).to receive(:new).and_return(layout)
  end

  it "uses its own content type and nested jobs" do
    expect(described_class::CONTENT_TYPE).to eq :full_download
    expect(described_class::NESTED_JOBS).to eq %w(DocumentPdfJob MaterialPdfJob FullDownloadBundleJob)
  end

  describe "#generate_dependants" do
    it "notes when the PDFs were queued, for the requeued run" do
      allow(DocumentPdfJob).to receive(:perform_later)
      allow(MaterialPdfJob).to receive(:perform_later)

      allow(Time).to receive(:current).and_return(Time.zone.at(1_000))

      job.send(:generate_dependants)

      expect(job.send(:options)[:dependants_queued_at]).to eq 1_000
    end

    it "renders each lesson and each material once" do
      allow(DocumentPdfJob).to receive(:perform_later)
      allow(MaterialPdfJob).to receive(:perform_later)

      job.send(:generate_dependants)

      options = { content_type: "full_download", initial_job_id: "job_1", renderer: "grover" }
      expect(DocumentPdfJob).to have_received(:perform_later).with(21, options)
      expect(DocumentPdfJob).to have_received(:perform_later).with(22, options)
      [11, 12, 13].each { expect(MaterialPdfJob).to have_received(:perform_later).with(it, options).once }
    end
  end

  describe "#generate_bundle" do
    let(:entries) { {} }
    let(:zip_url) { "https://s3.test/bundles/full_download/k_u1.zip" }

    before do
      allow(Exporters::Pdf::Unit).to receive(:new).and_return(instance_double(Exporters::Pdf::Unit, export: "unit pdf"))
      allow(S3Service).to receive(:read_data_from_s3) { |uri| "pdf from #{uri}" }
      allow(S3Service).to receive(:upload) do |_key, file, **|
        Zip::File.open(file.path) { |zip| zip.each { entries[it.name] = it.get_input_stream.read } }
        zip_url
      end
      allow(drive).to receive(:children).and_return([])
      allow(drive).to receive(:children).with("root_src").and_return([item.("r1", "Course Guide.pdf")])
      allow(drive).to receive(:children).with("unit_src")
        .and_return([item.("u1", "Unit Slides"), item.("u2", "Form"), item.("s1", "Section 1", folder: true)])
      allow(drive).to receive(:children).with("lesson_src").and_return([item.("l1", "worksheet.pdf")])
      allow(drive).to receive(:download) { |file| file.name == "Form" ? nil : [file.name.sub("Slides", "Slides.pptx"), "file #{file.id}"] }
      allow(unit).to receive(:reload).and_return(unit)
      allow(unit).to receive(:with_lock).and_yield
      allow(unit).to receive(:update)
    end

    it "zips the folder tree with the PDFs and the Non-LCMS files, and links the zip" do
      url = job.send(:generate_bundle)

      expect(DigitalAccess::Layout).to have_received(:new)
        .with(unit, drive:, output_root_id: nil, source_root_id: "SRCROOT123")
      expect(Exporters::Pdf::Unit).to have_received(:new).with(unit, { renderer: "grover" })
      expect(S3Service).to have_received(:upload)
        .with("bundles/full_download/k_u1.zip", anything, content_type: "application/zip")

      unit_dir = "OpenSciEd/Kindergarten Science/Unit 1"
      lesson_dir = "#{unit_dir}/Section 1 - Plants/Lesson 1: Seeds"
      expect(entries).to eq(
        "OpenSciEd/Kindergarten Science/Course Guide.pdf" => "file r1",
        "#{unit_dir}/unit.pdf" => "unit pdf",
        "#{unit_dir}/unit-material.pdf" => "pdf from https://s3.test/unit-material.pdf",
        "#{unit_dir}/Unit Slides.pptx" => "file u1",
        "#{unit_dir}/Section 1 - Plants/section-material.pdf" => "pdf from https://s3.test/section-material.pdf",
        "#{lesson_dir}/lesson-1.pdf" => "pdf from https://s3.test/lesson-1.pdf",
        "#{lesson_dir}/worksheet.pdf" => "pdf from https://s3.test/worksheet.pdf",
        "#{lesson_dir}/worksheet (2).pdf" => "file l1",
        "#{unit_dir}/Section 1 - Plants/Lesson 2/lesson-2.pdf" => "pdf from https://s3.test/lesson-2.pdf",
        "#{unit_dir}/Section 1 - Plants/Lesson 2/worksheet.pdf" => "pdf from https://s3.test/worksheet.pdf"
      )
      expect(url).to eq zip_url
      expect(unit).to have_received(:update) do |links:|
        expect(links.dig("full_download", "zip")).to include(url:, status: "completed")
      end
    end

    context "when a lesson has no PDF" do
      let(:lesson2) { pdf_record(22, "lesson-2.pdf", nil, lesson_materials: []) }

      it "fails naming the missing PDF" do
        expect { job.send(:generate_bundle) }.to raise_error(/PDFs failed to generate for: lesson-2.pdf/)
        expect(unit).not_to have_received(:update)
      end
    end

    context "when a lesson only has a PDF from an earlier run" do
      let(:lesson2) { pdf_record(22, "lesson-2.pdf", timestamp: 999, lesson_materials: []) }

      it "does not zip the old PDF" do
        job.send(:options)[:dependants_queued_at] = 1_000

        expect { job.send(:generate_bundle) }.to raise_error(/PDFs failed to generate for: lesson-2.pdf/)
      end
    end

    context "without a Download Root Folder Name" do
      let(:settings) { { non_lcms_root_url: nil } }

      it "uses the default top folder name" do
        job.send(:generate_bundle)

        expect(entries.keys).to all(start_with("Full Unit Content/Kindergarten Science/"))
      end
    end

    context "when a Non-LCMS file fails to download" do
      before do
        allow(drive).to receive(:download).with(have_attributes(id: "u1")).and_raise(Google::Apis::ClientError, "exportSizeLimitExceeded")
      end

      it "leaves it out and builds the rest" do
        job.send(:generate_bundle)

        expect(entries.keys).not_to include(a_string_ending_with("Unit Slides.pptx"))
        expect(entries.keys).to include("OpenSciEd/Kindergarten Science/Unit 1/unit.pdf")
      end
    end
  end
end
