# frozen_string_literal: true

require "rails_helper"

describe UnitBundleGdocJob do
  describe "class configuration" do
    it "has CONTENT_TYPE constant" do
      expect(described_class::CONTENT_TYPE).to eq :unit_bundle
    end

    it "has NESTED_JOBS constant" do
      expect(described_class::NESTED_JOBS).to eq %w(DocumentGdocJob MaterialGdocJob UnitBundleGdocJob)
    end

    it "has LINK_KEY constant" do
      expect(described_class::LINK_KEY).to eq "gdoc"
    end

    it "has BUNDLE_FOLDER constant" do
      expect(described_class::BUNDLE_FOLDER).to eq "bundles"
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
        s3_folder: "grade-2/module-1/unit-1",
        links: {}
      )
    end
    let(:drive_service) do
      double("Google::DriveService").tap do |ds|
        allow(ds).to receive(:create_folder).and_return("folder_id")
      end
    end

    before do
      job.instance_variable_set(:@unit, unit_presenter)
      job.instance_variable_set(:@options, { initial_job_id: "job_123" })
      allow(unit_presenter).to receive(:with_lock).and_yield
      allow(unit_presenter).to receive(:reload).and_return(unit_presenter)
      allow(unit_presenter).to receive(:update)
      allow(Google::DriveService).to receive(:new).and_return(drive_service)
    end

    describe "#generate_lessons" do
      it "enqueues DocumentGdocJob for each lesson" do
        job.instance_variable_set(:@unit_folder_id, "unit_folder_123")

        expect(DocumentGdocJob).to receive(:perform_later)
          .with(lesson1.id, hash_including(
            content_type: "unit_bundle",
            initial_job_id: "job_123",
            folder_id: "unit_folder_123"
          ))
        expect(DocumentGdocJob).to receive(:perform_later)
          .with(lesson2.id, hash_including(
            content_type: "unit_bundle",
            initial_job_id: "job_123",
            folder_id: "unit_folder_123"
          ))

        job.send(:generate_lessons)
      end
    end

    describe "#generate_materials" do
      let(:materials_folder_id) { "materials_folder_456" }

      before do
        job.instance_variable_set(:@unit_folder_id, "unit_folder_123")
        allow(drive_service).to receive(:create_folder)
          .with("materials", "unit_folder_123")
          .and_return(materials_folder_id)
      end

      it "creates materials subfolder in Google Drive" do
        allow(MaterialGdocJob).to receive(:perform_later)

        expect(drive_service).to receive(:create_folder)
          .with("materials", "unit_folder_123")
          .and_return(materials_folder_id)

        job.send(:generate_materials)
      end

      it "enqueues MaterialGdocJob for each material" do
        expect(MaterialGdocJob).to receive(:perform_later)
          .with(material1.id, hash_including(
            content_type: "unit_bundle",
            initial_job_id: "job_123",
            folder_id: materials_folder_id
          ))
        expect(MaterialGdocJob).to receive(:perform_later)
          .with(material2.id, hash_including(
            content_type: "unit_bundle",
            initial_job_id: "job_123",
            folder_id: materials_folder_id
          ))

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
      let(:unit_folder_id) { "unit_folder_789" }
      let(:gdoc_url) { "https://drive.google.com/open?id=unit_folder_789" }

      before do
        job.instance_variable_set(:@unit_folder_id, unit_folder_id)
        allow(Exporters::Gdoc::Base).to receive(:url_for)
          .with(unit_folder_id)
          .and_return(gdoc_url)
      end

      it "updates unit links with bundle URL" do
        expect(unit_presenter).to receive(:update) do |args|
          bundle_data = args[:links]["unit_bundle"]["gdoc"]
          expect(bundle_data[:url]).to eq gdoc_url
          expect(bundle_data[:status]).to eq "completed"
          expect(bundle_data[:timestamp]).to be_an(Integer)
          expect(bundle_data[:timestamp]).to be > 0
        end

        job.send(:generate_bundle)
      end

      it "returns the bundle URL" do
        result = job.send(:generate_bundle)
        expect(result).to eq gdoc_url
      end
    end

    describe "#unit_folder_id" do
      let(:bundles_id) { "bundles_folder_id" }
      let(:unit_bundle_id) { "unit_bundle_folder_id" }
      let(:s3_folder_id) { "s3_folder_id" }

      before do
        allow(drive_service).to receive(:create_folder)
          .with("bundles")
          .and_return(bundles_id)
        allow(drive_service).to receive(:create_folder)
          .with("unit_bundle", bundles_id)
          .and_return(unit_bundle_id)
        allow(drive_service).to receive(:create_folder)
          .with("grade-2/module-1/unit-1", unit_bundle_id)
          .and_return(s3_folder_id)
      end

      it "creates nested folder structure in Google Drive" do
        expect(drive_service).to receive(:create_folder).with("bundles").ordered
        expect(drive_service).to receive(:create_folder).with("unit_bundle", bundles_id).ordered
        expect(drive_service).to receive(:create_folder).with("grade-2/module-1/unit-1", unit_bundle_id).ordered

        job.send(:unit_folder_id)
      end

      it "returns the innermost folder ID" do
        result = job.send(:unit_folder_id)
        expect(result).to eq s3_folder_id
      end

      it "memoizes the result" do
        expect(drive_service).to receive(:create_folder).exactly(3).times

        2.times { job.send(:unit_folder_id) }
      end
    end

    describe "#drive_service" do
      it "creates a Google::DriveService instance" do
        job.instance_variable_set(:@drive_service, nil)

        expect(Google::DriveService).to receive(:new)
          .with(unit_presenter, {})
          .and_return(drive_service)

        job.send(:drive_service)
      end

      it "memoizes the result" do
        job.instance_variable_set(:@drive_service, nil)

        expect(Google::DriveService).to receive(:new).once.and_return(drive_service)

        2.times { job.send(:drive_service) }
      end
    end
  end
end
