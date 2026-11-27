# frozen_string_literal: true

require "rails_helper"

describe DigitalAccessBundleJob do
  let(:job) { described_class.new }
  let(:unit_material) { double("MaterialPresenter", id: 11) }
  let(:section_material) { double("MaterialPresenter", id: 12) }
  let(:lesson_material) { double("MaterialPresenter", id: 13, response?: false) }
  let(:response_links) { { "digital_access" => { "pdf" => { "url" => "https://s3.test/response.pdf", "timestamp" => 2_000 } } } }
  let(:response) do
    double("MaterialPresenter", id: 14, response?: true, pdf_filename: "response.pdf", reload: double(links: response_links))
  end
  let(:lesson) do
    double("DocumentPresenter", id: 21, lesson_materials: [lesson_material, response],
                                sample_responses_folder_name: "S2S_GK_01_Sample_Student_Responses")
  end
  let(:section) { instance_double(SectionPresenter, section_materials: [section_material]) }
  let(:unit) { double("UnitPresenter", unit_materials: [unit_material], links: {}) }
  let(:node) { DigitalAccess::Layout::Node }
  let(:course_node) do
    lesson_node = node.new(record: lesson, name: "Lesson 1", folder_id: "lesson_f", source_id: "lesson_src", children: [])
    section_node = node.new(record: section, name: "Section 1", folder_id: "section_f", source_id: nil, children: [lesson_node])
    unit_node = node.new(record: unit, name: "Unit 1", folder_id: "unit_f", source_id: "unit_src", children: [section_node])
    node.new(record: nil, name: "Course", folder_id: "course_f", source_id: "root_src", children: [unit_node])
  end
  let(:layout) { instance_double(DigitalAccess::Layout, build: course_node) }
  let(:drive) { instance_double(DigitalAccess::Drive, sync_copies: [], sync_pdfs: nil, folder: "responses_f") }
  let(:settings) do
    { digital_access_root_url: "https://drive.google.com/drive/folders/OUTROOT123",
      non_lcms_root_url: "https://drive.google.com/drive/folders/SRCROOT123" }
  end

  before do
    job.instance_variable_set(:@unit, unit)
    job.instance_variable_set(:@options, { initial_job_id: "job_1" })
    allow(Settings).to receive(:get).and_call_original
    allow(Settings).to receive(:get).with(:bundles, include_defaults: true).and_return(settings)
    allow(Google::DriveService).to receive(:new).and_return(double(service: :raw_service))
    allow(DigitalAccess::Drive).to receive(:new).with(:raw_service).and_return(drive)
    allow(DigitalAccess::Layout).to receive(:new).and_return(layout)
  end

  it "uses its own content type and nested jobs" do
    expect(described_class::CONTENT_TYPE).to eq :digital_access
    expect(described_class::NESTED_JOBS).to eq %w(DocumentGdocJob MaterialGdocJob MaterialPdfJob DigitalAccessBundleJob)
  end

  describe "#generate_dependants" do
    it "exports each lesson and material into its folder, and renders the responses as PDFs" do
      allow(DocumentGdocJob).to receive(:perform_later)
      allow(MaterialGdocJob).to receive(:perform_later)
      allow(MaterialPdfJob).to receive(:perform_later)

      job.send(:generate_dependants)

      options = ->(folder_id) { { content_type: "digital_access", initial_job_id: "job_1", folder_id: } }
      expect(DigitalAccess::Layout).to have_received(:new)
        .with(unit, drive:, output_root_id: "OUTROOT123", source_root_id: "SRCROOT123")
      expect(DocumentGdocJob).to have_received(:perform_later).with(21, options.("lesson_f"))
      expect(MaterialGdocJob).to have_received(:perform_later).with(11, options.("unit_f"))
      expect(MaterialGdocJob).to have_received(:perform_later).with(12, options.("section_f"))
      expect(MaterialGdocJob).to have_received(:perform_later).with(13, options.("lesson_f"))
      expect(MaterialGdocJob).not_to have_received(:perform_later).with(14, anything)
      expect(MaterialPdfJob).to have_received(:perform_later).with(14, { content_type: "digital_access", initial_job_id: "job_1" })
      expect(job.send(:options)[:dependants_queued_at]).to be_present
    end

    context "without the Digital Access Root Folder setting" do
      let(:settings) { { digital_access_root_url: nil } }

      it "fails with a message pointing at the setting" do
        expect { job.send(:generate_dependants) }.to raise_error(described_class::ConfigurationError, /Settings > Bundles/)
      end
    end
  end

  describe "#generate_bundle" do
    let(:exporter) { instance_double(Exporters::Gdoc::Unit, export: nil) }

    before do
      allow(S3Service).to receive(:read_data_from_s3) { |uri| "pdf from #{uri}" }
      allow(Exporters::Gdoc::Unit).to receive(:new).and_return(exporter)
      allow(unit).to receive(:reload).and_return(unit)
      allow(unit).to receive(:with_lock).and_yield
      allow(unit).to receive(:update)
    end

    it "exports the Teacher Bundle to Print into the unit folder, copies the Non-LCMS files and links the unit folder" do
      url = job.send(:generate_bundle)

      expect(Exporters::Gdoc::Unit).to have_received(:new).with(unit, folder_id: "unit_f")
      expect(drive).to have_received(:sync_copies).with("root_src", "course_f")
      expect(drive).to have_received(:sync_copies).with("unit_src", "unit_f")
      expect(drive).to have_received(:sync_copies).with(nil, "section_f")
      expect(drive).to have_received(:sync_copies).with("lesson_src", "lesson_f")
      expect(url).to eq "https://drive.google.com/open?id=unit_f"
      expect(unit).to have_received(:update) do |links:|
        expect(links.dig("digital_access", "gdoc")).to include(url:, status: "completed", skipped: [])
      end
    end

    it "puts the lesson's response PDFs in its Sample Student Responses folder" do
      job.send(:generate_bundle)

      expect(drive).to have_received(:folder).with("S2S_GK_01_Sample_Student_Responses", "lesson_f")
      expect(drive).to have_received(:sync_pdfs)
        .with("responses_f", { 14 => ["response.pdf", "pdf from https://s3.test/response.pdf"] })
    end

    context "when a response has no PDF from this run" do
      let(:response_links) { { "digital_access" => { "pdf" => { "url" => "https://s3.test/response.pdf", "timestamp" => 999 } } } }

      it "fails naming it" do
        job.send(:options)[:dependants_queued_at] = 1_000

        expect { job.send(:generate_bundle) }.to raise_error(/PDFs failed to generate for: response.pdf/)
        expect(drive).not_to have_received(:sync_pdfs)
        expect(unit).not_to have_received(:update)
      end
    end

    context "when Drive refuses to copy a Non-LCMS file" do
      before do
        form = DigitalAccess::Drive::Item.new(id: "f1", name: "Quiz <Form>")
        allow(drive).to receive(:sync_copies).with("lesson_src", "lesson_f").and_return([[form, "cannotCopyFile"]])
      end

      it "builds the rest, lists the file in the link and warns on the status page" do
        job.send(:generate_bundle)

        skipped = { folder: "Course/Unit 1/Section 1/Lesson 1", file: "Quiz <Form>", reason: "cannotCopyFile" }
        expect(unit).to have_received(:update) do |links:|
          expect(links.dig("digital_access", "gdoc", :skipped)).to eq [skipped]
        end
        expect(job.send(:bundle_warnings)).to eq [
          "1 Non-LCMS file was left out of the bundle:",
          "Course/Unit 1/Section 1/Lesson 1/Quiz &lt;Form&gt;: cannotCopyFile"
        ]
      end
    end
  end
end
