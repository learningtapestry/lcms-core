# frozen_string_literal: true

require "rails_helper"

describe MaterialForm do
  let(:credentials) { double }
  let(:material) { create :material }
  let(:service) { instance_double("MaterialBuildService", build: material, errors: []) }

  before { allow_any_instance_of(described_class).to receive(:google_credentials).and_return(credentials) }

  describe "#save" do
    subject { form.save }

    context "when is valid" do
      let(:link) { "doc-url" }
      let(:form) { described_class.new({ link: }, {}) }

      before do
        allow(MaterialBuildService).to receive(:new).and_return(service)
        allow(material).to receive(:update)
      end

      it "creates MaterialBuildService and builds the material" do
        expect(MaterialBuildService).to receive(:new).with(credentials, {}).and_return(service)
        expect(service).to receive(:build).with(link)
        subject
      end

      it "sets the material" do
        subject
        expect(form.material).to eq material
      end

      it "clears preview links" do
        expect(material).to receive(:update).with(preview_links: {})
        subject
      end
    end

    context "when is valid with import_retry option" do
      let(:form) { described_class.new({ link: "doc-url" }, { import_retry: true }) }

      before do
        allow(MaterialBuildService).to receive(:new).and_return(service)
        allow(material).to receive(:update)
      end

      it "passes import_retry to service" do
        expect(MaterialBuildService).to receive(:new).with(credentials, { import_retry: true })
        subject
      end
    end

    context "when there are non-critical errors" do
      let(:errors) { %w(error-1 error-2) }
      let(:service) { instance_double("MaterialBuildService", build: material, errors:) }
      let(:form) { described_class.new({ link: "doc-url" }, {}) }

      before do
        allow(MaterialBuildService).to receive(:new).and_return(service)
        allow(material).to receive(:update)
      end

      it "stores service errors" do
        subject
        expect(form.service_errors).to eq errors
      end
    end

    context "when is invalid" do
      let(:form) { described_class.new }

      it { is_expected.to be_falsey }
    end
  end
end
