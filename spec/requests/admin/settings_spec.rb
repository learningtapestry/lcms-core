# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Settings", type: :request do
  let(:admin) { create(:admin) }
  let(:settings_path) { "/admin/settings" }

  before { login_as(admin, scope: :user) }

  describe "authentication" do
    context "when not signed in" do
      before { logout }

      it "redirects to the sign-in page" do
        get settings_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as a non-admin user" do
      let(:user) { create(:user) }

      before do
        logout
        login_as(user, scope: :user)
      end

      it "redirects to root" do
        get settings_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /admin/settings (index)" do
    it "returns a successful response" do
      get settings_path
      expect(response).to have_http_status(:ok)
    end

    it "displays settings from all groups" do
      Setting.set(:appearance, { "header_bg_color" => "#ff0000" })

      get settings_path

      expect(response.body).to include("#ff0000")
    end
  end

  describe "PATCH /admin/settings (update)" do
    it "saves settings and redirects with a success notice" do
      patch settings_path, params: { header_bg_color: "#ff0000" }

      expect(response).to redirect_to(settings_path)
      follow_redirect!
      expect(response.body).to include("Setting updated successfully")

      setting = Setting.find_by(key: "appearance")
      expect(setting.value["header_bg_color"]).to eq("#ff0000")
    end

    it "updates multiple settings at once" do
      patch settings_path, params: {
        header_bg_color: "#ff0000",
        header_text_color: "#00ff00"
      }

      expect(response).to redirect_to(settings_path)
      setting = Setting.find_by(key: "appearance")
      expect(setting.value["header_bg_color"]).to eq("#ff0000")
      expect(setting.value["header_text_color"]).to eq("#00ff00")
    end

    it "does not persist non-permitted params" do
      patch settings_path, params: { some_random_key: "value" }

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "appearance")).to be_nil
    end

    context "with image upload" do
      let(:uploader) { instance_double(ImageUploader, store!: true, url: "/uploads/settings/image.png") }
      let(:image_file) do
        Tempfile.new(["test_image", ".png"]).tap do |f|
          f.binmode
          f.write("\x89PNG\r\n\x1a\n")
          f.rewind
        end
      end
      let(:uploaded_file) { Rack::Test::UploadedFile.new(image_file.path, "image/png") }

      before do
        allow(ImageUploader).to receive(:new).and_return(uploader)
      end

      after { image_file.close! }

      it "processes the image upload and stores its URL as a setting" do
        patch settings_path, params: { header_logo: uploaded_file }

        expect(response).to redirect_to(settings_path)
        expect(uploader).to have_received(:store!)
        setting = Setting.find_by(key: "appearance")
        expect(setting.value["header_logo"]).to eq("/uploads/settings/image.png")
      end

      it "deletes the old image before storing a new one" do
        Setting.set(:appearance, { "header_logo" => "/uploads/settings/old_image.png" })
        old_path = Rails.root.join("public", "uploads/settings/old_image.png")
        allow(old_path).to receive(:exist?).and_return(false)

        patch settings_path, params: { header_logo: uploaded_file }

        expect(response).to redirect_to(settings_path)
        setting = Setting.find_by(key: "appearance")
        expect(setting.value["header_logo"]).to eq("/uploads/settings/image.png")
      end
    end
  end

  describe "DELETE /admin/settings/:key (destroy)" do
    it "resets a setting and redirects" do
      Setting.set(:appearance, { "header_bg_color" => "#ff0000", "header_text_color" => "#000000" })

      delete "#{settings_path}/header_bg_color"

      expect(response).to redirect_to(settings_path)
      follow_redirect!
      expect(response.body).to include("Setting deleted successfully")

      setting = Setting.find_by(key: "appearance")
      expect(setting.value).not_to have_key("header_bg_color")
      expect(setting.value["header_text_color"]).to eq("#000000")
    end

    it "handles deletion when no settings exist gracefully" do
      delete "#{settings_path}/header_bg_color"
      expect(response).to redirect_to(settings_path)
    end

    context "when deleting an image setting with a local file" do
      before do
        Setting.set(:appearance, { "header_logo" => "/uploads/settings/image.png", "header_bg_color" => "#ffffff" })
      end

      it "removes the setting value" do
        delete "#{settings_path}/header_logo"

        setting = Setting.find_by(key: "appearance")
        expect(setting.value).not_to have_key("header_logo")
      end

      it "deletes the local file" do
        local_path = Rails.root.join("public", "uploads/settings/image.png")
        FileUtils.mkdir_p(local_path.dirname)
        FileUtils.touch(local_path)

        delete "#{settings_path}/header_logo"

        expect(File.exist?(local_path)).to be false
      end
    end

    context "when deleting an image setting with an S3 URL" do
      before do
        Setting.set(:appearance, { "header_logo" => "https://bucket.s3.amazonaws.com/uploads/settings/image.png", "header_bg_color" => "#ffffff" })
        allow(S3Service).to receive(:delete_object)
      end

      it "removes the setting and calls S3Service.delete_object" do
        delete "#{settings_path}/header_logo"

        expect(S3Service).to have_received(:delete_object).with("uploads/settings/image.png")
        setting = Setting.find_by(key: "appearance")
        expect(setting.value).not_to have_key("header_logo")
      end
    end
  end

  describe "POST /admin/settings/upload_image" do
    let(:uploader) { instance_double(ImageUploader, store!: true, url: "/uploads/settings/image.png") }
    let(:image_file) do
      Tempfile.new(["test_image", ".png"]).tap do |f|
        f.binmode
        f.write("\x89PNG\r\n\x1a\n")
        f.rewind
      end
    end
    let(:uploaded_file) { Rack::Test::UploadedFile.new(image_file.path, "image/png") }

    before do
      allow(ImageUploader).to receive(:new).and_return(uploader)
    end

    after { image_file.close! }

    it "uploads the image and returns JSON with URL" do
      post "#{settings_path}/upload_image", params: { image: uploaded_file }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["url"]).to eq("/uploads/settings/image.png")
    end

    it "returns 422 when no file is provided" do
      post "#{settings_path}/upload_image", params: { image: "not_a_file" }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when CarrierWave raises an IntegrityError" do
      allow(uploader).to receive(:store!).and_raise(CarrierWave::IntegrityError, "Invalid file type")

      post "#{settings_path}/upload_image", params: { image: uploaded_file }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("Invalid file type")
    end
  end
end
