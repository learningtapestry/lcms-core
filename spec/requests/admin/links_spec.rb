# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Links", type: :request do
  let(:admin) { create(:admin) }

  before { login_as(admin, scope: :user) }

  describe "GET /admin/links" do
    it "lists the links, filtered by id" do
      create(:link, identifier: "nasa-01", text: "NASA website")
      create(:link, identifier: "noaa-01")

      get admin_links_path(q: "nasa")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("nasa-01", "NASA website")
      expect(response.body).not_to include("noaa-01")
    end
  end

  describe "POST /admin/links/import" do
    it "imports the sheet and reports the count" do
      allow(LinksImportService).to receive(:call).with("https://docs.google.com/spreadsheets/d/x") { create(:link) }

      post import_admin_links_path, params: { link_form: { link: "https://docs.google.com/spreadsheets/d/x" } }

      expect(response).to redirect_to(admin_links_path)
      expect(flash[:notice]).to eq "Imported 1 URL"
    end

    it "shows the import error" do
      allow(LinksImportService).to receive(:call).and_raise(LinksImportService::ImportError, "Row 3 (bad): Url is invalid")

      post import_admin_links_path, params: { link_form: { link: "https://docs.google.com/spreadsheets/d/x" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Row 3 (bad): Url is invalid")
    end
  end

  it "is admin-only" do
    logout
    login_as(create(:user), scope: :user)

    get admin_links_path

    expect(response).to redirect_to(root_path)
  end
end
