# frozen_string_literal: true

require "rails_helper"

describe UnitBundlePdfJob do
  describe "class configuration" do
    it "has CONTENT_TYPE constant" do
      expect(described_class::CONTENT_TYPE).to eq :unit_bundle
    end

    it "has NESTED_JOBS constant" do
      expect(described_class::NESTED_JOBS).to eq %w(DocumentPdfJob MaterialPdfJob UnitBundlePdfJob)
    end

    it "has LINK_KEY constant" do
      expect(described_class::LINK_KEY).to eq "pdf"
    end

    it "inherits from BaseBundleJob" do
      expect(described_class.superclass).to eq BaseBundleJob
    end

    it "includes UnitLevelJob" do
      expect(described_class.ancestors).to include(UnitLevelJob)
    end
  end

  describe "#perform" do
    let(:unit) { create(:resource, curriculum_type: "unit") }
    let(:options) { {} }

    before do
      allow_any_instance_of(described_class).to receive(:perform_generation_for)
    end

    it "calls perform_generation_for with entry_id and options" do
      expect_any_instance_of(described_class).to receive(:perform_generation_for)
        .with(unit.id, options)

      described_class.new.perform(unit.id, options)
    end
  end

  describe "private methods" do
    let(:unit) { create(:resource, curriculum_type: "unit") }
    let(:lesson1) { create(:resource, curriculum_type: "lesson") }
    let(:lesson2) { create(:resource, curriculum_type: "lesson") }
    let(:material1) { create(:material) }
    let(:material2) { create(:material) }
    let(:job) { described_class.new }
    let(:unit_presenter) do
      double(
        "UnitPresenter",
        id: unit.id,
        lessons: [lesson1, lesson2],
        materials: [material1, material2],
        bundle_folder: "units/test-unit",
        links: {},
        reload: nil
      )
    end

    before do
      job.instance_variable_set(:@unit, unit_presenter)
      job.instance_variable_set(:@options, { initial_job_id: "job_123" })
      allow(unit_presenter).to receive(:with_lock).and_yield
      allow(unit_presenter).to receive(:reload).and_return(unit_presenter)
      allow(unit_presenter).to receive(:update)
    end

    describe "#generate_lessons" do
      it "enqueues DocumentPdfJob for each lesson" do
        expect(DocumentPdfJob).to receive(:perform_later)
          .with(lesson1.id, hash_including(content_type: "unit_bundle", initial_job_id: "job_123"))
        expect(DocumentPdfJob).to receive(:perform_later)
          .with(lesson2.id, hash_including(content_type: "unit_bundle", initial_job_id: "job_123"))

        job.send(:generate_lessons)
      end
    end

    describe "#generate_materials" do
      it "enqueues MaterialPdfJob for each material" do
        expect(MaterialPdfJob).to receive(:perform_later)
          .with(material1.id, hash_including(content_type: "unit_bundle", initial_job_id: "job_123"))
        expect(MaterialPdfJob).to receive(:perform_later)
          .with(material2.id, hash_including(content_type: "unit_bundle", initial_job_id: "job_123"))

        job.send(:generate_materials)
      end
    end

    describe "#generate_dependants" do
      it "generates both lessons and materials" do
        expect(job).to receive(:generate_lessons)
        expect(job).to receive(:generate_materials)

        job.send(:generate_dependants)
      end
    end

    describe "#generate_bundle" do
      let(:lesson1_with_links) do
        double(
          pdf_filename: "lesson1.pdf",
          links: { "unit_bundle" => { "pdf" => { "url" => "https://s3.example.com/lesson1.pdf" } } }
        )
      end
      let(:lesson2_with_links) do
        double(
          pdf_filename: "lesson2.pdf",
          links: { "unit_bundle" => { "pdf" => { "url" => "https://s3.example.com/lesson2.pdf" } } }
        )
      end
      let(:material1_with_links) do
        double(
          pdf_filename: "material1.pdf",
          links: { "unit_bundle" => { "pdf" => { "url" => "https://s3.example.com/material1.pdf" } } }
        )
      end
      let(:material2_with_links) do
        double(
          pdf_filename: "material2.pdf",
          links: {}
        )
      end
      let(:unit_presenter_with_resources) do
        double(
          "UnitPresenter",
          id: unit.id,
          lessons: [lesson1_with_links, lesson2_with_links],
          materials: [material1_with_links, material2_with_links],
          bundle_folder: "units/test-unit",
          links: {}
        )
      end
      let(:bundle_url) { "https://s3.example.com/units/test-unit" }

      before do
        job.instance_variable_set(:@unit, unit_presenter_with_resources)
        allow(unit_presenter_with_resources).to receive(:with_lock).and_yield
        allow(unit_presenter_with_resources).to receive(:reload).and_return(unit_presenter_with_resources)
        allow(unit_presenter_with_resources).to receive(:update)

        allow(S3Service).to receive(:read_data_from_s3).and_return("pdf_data")
        allow(S3Service).to receive(:upload)
        allow(S3Service).to receive(:url_for).and_return(bundle_url)
      end

      it "copies lesson PDFs to bundle folder" do
        expect(S3Service).to receive(:upload)
          .with("units/test-unit/lesson1.pdf", "pdf_data", content_type: "application/pdf")
        expect(S3Service).to receive(:upload)
          .with("units/test-unit/lesson2.pdf", "pdf_data", content_type: "application/pdf")

        job.send(:generate_bundle)
      end

      it "copies material PDFs to bundle materials subfolder" do
        expect(S3Service).to receive(:upload)
          .with("units/test-unit/materials/material1.pdf", "pdf_data", content_type: "application/pdf")

        job.send(:generate_bundle)
      end

      it "skips materials without PDF links" do
        expect(S3Service).not_to receive(:upload)
          .with("units/test-unit/materials/material2.pdf", anything, anything)

        job.send(:generate_bundle)
      end

      it "updates unit links with bundle URL" do
        expect(unit_presenter_with_resources).to receive(:update) do |args|
          bundle_data = args[:links]["pdf_bundle"]["unit_bundle"]["pdf"]
          expect(bundle_data[:url]).to eq bundle_url
          expect(bundle_data[:status]).to eq "completed"
        end

        job.send(:generate_bundle)
      end

      it "returns the bundle URL" do
        result = job.send(:generate_bundle)
        expect(result).to eq bundle_url
      end
    end

    describe "#copy_pdf_to_bundle" do
      let(:source_url) { "https://s3.example.com/source.pdf" }
      let(:bundle_folder) { "units/test-unit" }
      let(:filename) { "lesson.pdf" }

      before do
        allow(S3Service).to receive(:read_data_from_s3).and_return("pdf_data")
        allow(S3Service).to receive(:upload)
      end

      it "reads PDF from source URL" do
        expect(S3Service).to receive(:read_data_from_s3)
          .with(URI.parse(source_url))
          .and_return("pdf_data")

        job.send(:copy_pdf_to_bundle, source_url: source_url, bundle_folder: bundle_folder, filename: filename)
      end

      it "uploads PDF to target location" do
        expect(S3Service).to receive(:upload)
          .with("units/test-unit/lesson.pdf", "pdf_data", content_type: "application/pdf")

        job.send(:copy_pdf_to_bundle, source_url: source_url, bundle_folder: bundle_folder, filename: filename)
      end

      it "logs error on failure but does not raise" do
        allow(S3Service).to receive(:read_data_from_s3).and_raise(StandardError.new("Network error"))
        expect(Rails.logger).to receive(:error).with(/Failed to copy PDF/)

        expect {
          job.send(:copy_pdf_to_bundle, source_url: source_url, bundle_folder: bundle_folder, filename: filename)
        }.not_to raise_error
      end
    end
  end
end
