# frozen_string_literal: true

require "rails_helper"

describe MaterialsController do
  let(:user) { create :admin }
  let(:material) { create :material }
  let(:job_id) { "job_xyz_456" }

  before { sign_in user }

  describe "#preview_pdf" do
    render_views

    let(:enqueued_job) { instance_double(MaterialPdfJob, job_id: job_id) }

    before { allow(MaterialPdfJob).to receive(:perform_later).and_return(enqueued_job) }

    around do |example|
      original = ENV["FORCE_PREVIEW_GENERATION"]
      ENV["FORCE_PREVIEW_GENERATION"] = "true"
      example.run
    ensure
      ENV["FORCE_PREVIEW_GENERATION"] = original
    end

    it "enqueues a MaterialPdfJob via perform_later (not perform_now)" do
      expect(MaterialPdfJob)
        .to receive(:perform_later)
        .with(material.id, hash_including(content_type: :preview, preview: true))
        .and_return(enqueued_job)
      expect(MaterialPdfJob).not_to receive(:perform_now)

      get :preview_pdf, params: { id: material.id }
    end

    it "responds with a 200 instead of redirecting (async flow)" do
      get :preview_pdf, params: { id: material.id }
      expect(response).to have_http_status(:ok)
    end

    it "embeds the generic job-status URL so the page can poll" do
      get :preview_pdf, params: { id: material.id }
      expect(response.body).to include(status_api_document_job_path(job_id))
    end
  end
end
