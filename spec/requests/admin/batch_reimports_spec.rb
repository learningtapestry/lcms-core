# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::BatchReimports", type: :request do
  before { login_as(create(:admin), scope: :user) }

  describe "GET /admin/batch_reimport/new" do
    it "renders the search form with subjects and grades keyed as lessons store them" do
      get new_admin_batch_reimport_path

      expect(response).to have_http_status(:ok)
      SUBJECTS.each do |key, name|
        expect(response.body).to include(%(<option value="#{key}">#{name}</option>))
      end
      expect(response.body).to include(%(<option value="k">Kindergarten</option>), %(<option value="6">Grade 6</option>))
    end
  end

  describe "POST /admin/batch_reimport" do
    def reimport(query)
      post admin_batch_reimport_path, params: { query: }
    end

    context "with lessons" do
      let(:lesson_metadata) { { "subject" => "math", "grade" => "6", "unit" => "u1", "section" => "s1" } }
      let!(:match) { create(:document, metadata: lesson_metadata) }

      before do
        create(:document, metadata: lesson_metadata.merge("subject" => "science"))
        create(:document, metadata: lesson_metadata.merge("grade" => "7"))
        create(:document, metadata: lesson_metadata.merge("unit" => "u2"))
        create(:document, metadata: lesson_metadata.merge("section" => "s2"))
        allow(DocumentParseJob).to receive(:perform_later)
          .and_return(instance_double(DocumentParseJob, job_id: "job-1"))
      end

      it "queues only the lesson matching every filter" do
        reimport(subject: "math", grade: "6", unit: "u1", section: "s1", type: "documents")

        expect(response).to have_http_status(:ok)
        expect(DocumentParseJob).to have_received(:perform_later).once.with(match.file_url)
      end

      it "lets the lesson query apply its default curriculum order" do
        allow(DocTemplate.document_query).to receive(:call).and_call_original

        reimport(subject: "math", type: "documents")

        expect(DocTemplate.document_query).to have_received(:call).with(having_attributes(sort_by: nil))
      end

      it "matches kindergarten lessons" do
        kindergarten = create(:document, metadata: lesson_metadata.merge("grade" => "k"))

        reimport(subject: "math", grade: "k", unit: "u1", section: "s1", type: "documents")

        expect(DocumentParseJob).to have_received(:perform_later).once.with(kindergarten.file_url)
      end

      it "redirects back to the same search when nothing matches" do
        reimport(subject: "math", grade: "6", unit: "u1", section: "missing", type: "documents")

        expect(DocumentParseJob).not_to have_received(:perform_later)
        expect(response).to redirect_to(new_admin_batch_reimport_path(
          query: { grade: "6", section: "missing", subject: "math", unit: "u1", type: "documents" }
        ))
      end
    end

    context "with materials" do
      let!(:match) { create(:material, metadata: { "subject" => "math", "grade" => "6" }) }

      before do
        create(:material, metadata: { "subject" => "science", "grade" => "6" })
        create(:material, metadata: { "subject" => "math", "grade" => "7" })
        allow(MaterialParseJob).to receive(:perform_later)
          .and_return(instance_double(MaterialParseJob, job_id: "job-1"))
      end

      it "queues only the materials matching subject and grade" do
        reimport(subject: "math", grade: "6", type: "materials")

        expect(response).to have_http_status(:ok)
        expect(MaterialParseJob).to have_received(:perform_later).once.with(match.file_url)
      end

      it "refuses unit and section filters instead of ignoring them, keeping Type and Grade" do
        reimport(subject: "math", grade: "6", unit: "u1", type: "materials")

        expect(MaterialParseJob).not_to have_received(:perform_later)
        expect(response).to redirect_to(new_admin_batch_reimport_path(
          query: { grade: "6", subject: "math", unit: "u1", type: "materials" }
        ))
        expect(flash[:alert]).to eq(I18n.t("admin.batch_reimports.create.lesson_only_filters"))
      end
    end
  end
end
