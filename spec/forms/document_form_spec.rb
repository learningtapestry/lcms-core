# frozen_string_literal: true

require "rails_helper"

describe DocumentForm do
  let(:credentials) { double }
  let(:form) { described_class.new(params, options) }
  let(:options) { {} }

  before { allow_any_instance_of(described_class).to receive(:google_credentials).and_return(credentials) }

  describe "#save" do
    let(:document) { create :document }
    let(:service) { instance_double("DocumentBuildService", build_for: document, errors: []) }

    subject { form.save }

    context "when is valid" do
      let(:link) { "doc-url" }
      let(:params) { { link: } }

      before do
        # allow(DocumentGenerator).to receive(:generate_for)
        allow(DocumentBuildService).to receive(:new).and_return(service)
      end

      it "creates DocumentBuildService object" do
        expect(DocumentBuildService).to receive(:new).with(credentials, import_retry: nil)
                                                        .and_return(service)
        subject
      end

      it "builds the document" do
        subject
        expect(form.document).to eq document
      end

      it "marks the document as reimported" do
        document.update reimported: false
        subject
        expect(document.reload.reimported).to be_truthy
      end

      context "when that is re-import operation" do
        it "calls service sequentially to import both type of links" do
          expect(service).to receive(:build_for).with(params[:link])
          subject
        end
      end

      context "when there are non-critical errors" do
        let(:errors) { %w(error-1 error-2 error-3) }
        let(:service) { instance_double("DocumentBuildService", build_for: document, errors:) }

        it "store service errors" do
          subject
          expect(form.service_errors).to eq errors
        end
      end
    end

    context "when is invalid" do
      let(:params) { {} }

      it { is_expected.to be_falsey }
    end
  end
end
