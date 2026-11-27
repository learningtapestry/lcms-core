# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Standards", type: :request do
  before { login_as(create(:admin), scope: :user) }

  describe "GET /admin/standards" do
    it "lists standards with their description and filters by name" do
      create(:standard, name: "RL.2.2", description: "Recount stories.", alt_names: %w(ela.rl.2.2))
      create(:standard, name: "8.EE.1")

      get admin_standards_path, params: { query: { name: "rl.2" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("RL.2.2", "Recount stories.", "ela.rl.2.2")
      expect(response.body).not_to include("8.EE.1")
    end
  end

  describe "POST /admin/standards/import" do
    let(:link) { "https://docs.google.com/spreadsheets/d/x" }

    it "imports the sheet and reports the count" do
      allow(ImportService).to receive(:call).and_return("Code,Description\nRL.2.2,Recount stories.\n")

      post import_admin_standards_path, params: { standard_form: { link: } }

      expect(response).to redirect_to(admin_standards_path)
      expect(flash[:notice]).to eq("Imported 1 standard.")
    end

    it "shows the import error escaped and keeps the current standards" do
      create(:standard, name: "K.1")
      allow(ImportService).to receive(:call).and_return("Code,Description\n<b>x</b>,a\n<b>x</b>,b\n")

      post import_admin_standards_path, params: { standard_form: { link: } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Row 3 (&lt;b&gt;x&lt;/b&gt;)")
      expect(Standard.pluck(:name)).to eq %w(K.1)
    end
  end

  describe "PATCH /admin/standards/:id" do
    it "updates the description" do
      standard = create(:standard)

      patch admin_standard_path(standard), params: { standard: { description: "Edited" } }

      expect(response).to redirect_to(admin_standards_path)
      expect(standard.reload.description).to eq("Edited")
    end
  end
end
