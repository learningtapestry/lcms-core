# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Images", type: :request do
  let(:admin) { create(:admin) }

  before { login_as(admin, scope: :user) }

  describe "GET /admin/images" do
    it "lists the images, filtered by id" do
      create(:image, identifier: "mountain-01", caption: "Mountain")
      create(:image, identifier: "lake-01")

      get admin_images_path(q: "mount")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("mountain-01", "Mountain")
      expect(response.body).not_to include("lake-01")
    end
  end

  describe "POST /admin/images/import" do
    it "imports the sheet and reports the count" do
      allow(ImagesImportService).to receive(:call).with("https://docs.google.com/spreadsheets/d/x") { create(:image) }

      post import_admin_images_path, params: { image_form: { link: "https://docs.google.com/spreadsheets/d/x" } }

      expect(response).to redirect_to(admin_images_path)
      expect(flash[:notice]).to eq "Imported 1 image"
    end

    it "shows the import error" do
      allow(ImagesImportService).to receive(:call).and_raise(ImagesImportService::ImportError, "Row 3 (bad): File url is invalid")

      post import_admin_images_path, params: { image_form: { link: "https://docs.google.com/spreadsheets/d/x" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Row 3 (bad): File url is invalid")
    end
  end

  it "is admin-only" do
    logout
    login_as(create(:user), scope: :user)

    get admin_images_path

    expect(response).to redirect_to(root_path)
  end
end
