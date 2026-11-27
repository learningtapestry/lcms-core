# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Sections", type: :request do
  let(:admin) { create(:admin) }
  let(:section) do
    create(:resource,
           curriculum_type: "section",
           links: { "source" => { "gdoc" => { "name" => "Section 1 Metadata",
                                              "url" => "https://docs.google.com/document/d/xyz" } } },
           metadata: { "subject" => "math", "grade" => "grade 2", "unit" => "unit 1", "section" => "1",
                       "section_number" => "1", "section_title" => "Adding Fractions",
                       "section_title_spanish" => "Sumar fracciones", "material_ids" => %w(s1 s2),
                       "description" => "<script>alert(1)</script><p>Overview</p>" })
  end

  before { login_as(admin, scope: :user) }

  describe "GET /admin/sections/:id" do
    it "shows the section and everything its import stored" do
      get admin_section_path(section)

      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body).to include("Adding Fractions", "section_title_spanish", "Sumar fracciones", "s1, s2")
      expect(body).to include("<p>Overview</p>", "Section 1 Metadata", "https://docs.google.com/document/d/xyz")
      expect(body).not_to include("<script>alert(1)</script>")
    end

    it "redirects a non-admin" do
      logout
      login_as(create(:user), scope: :user)

      get admin_section_path(section)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /admin/sections" do
    it "links each section to its details page" do
      section
      get admin_sections_path

      expect(response.body).to include(admin_section_path(section))
    end
  end

  describe "POST /admin/sections/:id/reimport" do
    before do
      allow(SectionParseJob).to receive(:perform_later).and_return(instance_double(SectionParseJob, job_id: "job-1"))
    end

    it "queues a parse job for the source document and shows the import status page" do
      post reimport_admin_section_path(section)

      expect(SectionParseJob).to have_received(:perform_later).with("https://docs.google.com/document/d/xyz")
      expect(response).to have_http_status(:ok)
    end

    it "shows an enabled Reimport button on the details page" do
      get admin_section_path(section)

      expect(response.body).to include(reimport_admin_section_path(section))
    end

    context "when the section has no source document" do
      before { section.update!(links: {}) }

      it "redirects back to the details page without queueing a job" do
        post reimport_admin_section_path(section)

        expect(SectionParseJob).not_to have_received(:perform_later)
        expect(response).to redirect_to(admin_section_path(section))
        expect(flash[:alert]).to eq(I18n.t("admin.shared.reimport.no_source"))
      end

      it "shows a disabled Reimport button on the details page" do
        get admin_section_path(section)

        expect(response.body).not_to include(reimport_admin_section_path(section))
        expect(response.body).to include(I18n.t("admin.shared.reimport.no_source"))
      end
    end
  end
end
