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
      Settings.set(:appearance, { "header_bg_color" => "#ff0000" })

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

    it "rolls back already-applied flat-group changes when a form group is invalid" do
      # A :form group can fail validation after earlier flat groups in the
      # SETTINGS loop have already been written; the whole save must roll back
      # so the rejected submit leaves no partial write.
      allow_any_instance_of(Setting::AdminViewLinks).to receive(:valid?).and_return(false)

      patch settings_path, params: {
        header_bg_color: "#abcdef",
        admin_view_links: { documents: "/x/:id" }
      }

      expect(response).to have_http_status(:unprocessable_content)
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
        Settings.set(:appearance, { "header_logo" => "/uploads/settings/old_image.png" })
        old_path = Rails.root.join("public", "uploads/settings/old_image.png")
        allow(old_path).to receive(:exist?).and_return(false)

        patch settings_path, params: { header_logo: uploaded_file }

        expect(response).to redirect_to(settings_path)
        setting = Setting.find_by(key: "appearance")
        expect(setting.value["header_logo"]).to eq("/uploads/settings/image.png")
      end

      it "uploads nothing and persists nothing when a form group is invalid (no orphan, no partial write)" do
        allow_any_instance_of(Setting::AdminViewLinks).to receive(:valid?).and_return(false)

        patch settings_path, params: {
          header_logo: uploaded_file,
          admin_view_links: { documents: "/x/:id" }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(uploader).not_to have_received(:store!)
        expect(Setting.find_by(key: "appearance")).to be_nil
      end
    end
  end

  describe "DELETE /admin/settings/:key (destroy)" do
    it "resets a setting and redirects" do
      Settings.set(:appearance, { "header_bg_color" => "#ff0000", "header_text_color" => "#000000" })

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
        Settings.set(:appearance, { "header_logo" => "/uploads/settings/image.png", "header_bg_color" => "#ffffff" })
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
        Settings.set(:appearance, { "header_logo" => "https://bucket.s3.amazonaws.com/uploads/settings/image.png", "header_bg_color" => "#ffffff" })
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

  describe "documents lesson_types field (:key_value_list)" do
    it "renders a row per existing entry, plus the submitted sentinel" do
      Settings.set(:documents, "lesson_types" => { "AP" => "Anchoring Phenomenon" })

      get settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="lesson_types[][abbr]"')
      expect(response.body).to include('name="lesson_types[][label]"')
      expect(response.body).to include('name="lesson_types_submitted"')
      expect(response.body).to include("Anchoring Phenomenon")
    end

    it "persists submitted rows as an ordered abbr => label Hash" do
      patch settings_path, params: {
        lesson_types_submitted: "1",
        lesson_types: [
          { abbr: "AP", label: "Anchoring Phenomenon" },
          { abbr: "CMB", label: "Class Model Building" }
        ]
      }

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "documents").value["lesson_types"]).to eq(
        "AP" => "Anchoring Phenomenon",
        "CMB" => "Class Model Building"
      )
    end

    it "drops rows with a blank abbreviation or label" do
      patch settings_path, params: {
        lesson_types_submitted: "1",
        lesson_types: [
          { abbr: "AP", label: "Anchoring Phenomenon" },
          { abbr: "", label: "Missing abbr" },
          { abbr: "NL", label: "" }
        ]
      }

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "documents").value["lesson_types"]).to eq("AP" => "Anchoring Phenomenon")
    end

    it "leaves the stored map untouched when the field is omitted" do
      Settings.set(:documents, "lesson_types" => { "AP" => "Anchoring Phenomenon" })

      patch settings_path, params: { copyright_text: "© Acme" }

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "documents").value["lesson_types"]).to eq("AP" => "Anchoring Phenomenon")
    end
  end

  describe "documents student_groupings field (:label_map)" do
    it "renders one row per fixed GROUPING_OPTIONS key, pre-filled from the stored map" do
      Settings.set(:documents, "student_groupings" => { "class" => "Whole Class" })

      get settings_path

      expect(response).to have_http_status(:ok)
      DocTemplate::Tables::Activity::GROUPING_OPTIONS.each do |key|
        expect(response.body).to include(%(name="student_groupings[#{key}]"))
      end
      expect(response.body).to include("Whole Class")
    end

    it "persists submitted labels as a key => label Hash" do
      patch settings_path, params: {
        student_groupings: { "class" => "Whole Class", "small group" => "Small Groups" }
      }

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "documents").value["student_groupings"]).to eq(
        "class" => "Whole Class",
        "small group" => "Small Groups"
      )
    end

    it "drops blank labels, leaving unconfigured keys absent" do
      patch settings_path, params: {
        student_groupings: { "class" => "Whole Class", "individual" => "" }
      }

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "documents").value["student_groupings"]).to eq("class" => "Whole Class")
    end

    it "ignores a key outside the fixed GROUPING_OPTIONS vocabulary" do
      patch settings_path, params: {
        student_groupings: { "class" => "Whole Class", "bogus" => "Nope" }
      }

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "documents").value["student_groupings"]).to eq("class" => "Whole Class")
    end

    it "leaves the stored map untouched when the field is omitted" do
      Settings.set(:documents, "student_groupings" => { "class" => "Whole Class" })

      patch settings_path, params: { copyright_text: "© Acme" }

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "documents").value["student_groupings"]).to eq("class" => "Whole Class")
    end
  end

  describe "documents callout_types field (:callout_list)" do
    it "renders a row per existing entry, plus the submitted sentinel" do
      Settings.set(:documents, "callout_types" => [{ "type" => "tip", "title" => "Teaching Tip" }])

      get settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="callout_types[][type]"')
      expect(response.body).to include('name="callout_types[][title]"')
      expect(response.body).to include('name="callout_types[][image]"')
      expect(response.body).to include('name="callout_types_submitted"')
      expect(response.body).to include("Teaching Tip")
    end

    it "persists submitted rows as an ordered Array of type/title/image Hashes" do
      patch settings_path, params: {
        callout_types_submitted: "1",
        callout_types: [
          { type: "tip", title: "Teaching Tip" },
          { type: "custom", title: "Custom Type" }
        ]
      }

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "documents").value["callout_types"]).to eq(
        [
          { "type" => "tip", "title" => "Teaching Tip", "image" => nil },
          { "type" => "custom", "title" => "Custom Type", "image" => nil }
        ]
      )
    end

    it "drops rows with a blank type" do
      patch settings_path, params: {
        callout_types_submitted: "1",
        callout_types: [
          { type: "tip", title: "Teaching Tip" },
          { type: "", title: "Missing type" }
        ]
      }

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "documents").value["callout_types"]).to eq(
        [{ "type" => "tip", "title" => "Teaching Tip", "image" => nil }]
      )
    end

    it "leaves the stored list untouched when the field is omitted" do
      Settings.set(:documents, "callout_types" => [{ "type" => "tip", "title" => "Teaching Tip" }])

      patch settings_path, params: { copyright_text: "© Acme" }

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "documents").value["callout_types"]).to eq(
        [{ "type" => "tip", "title" => "Teaching Tip" }]
      )
    end

    it "clears the list when the sentinel is submitted with no rows" do
      Settings.set(:documents, "callout_types" => [{ "type" => "tip", "title" => "Teaching Tip" }])

      patch settings_path, params: { callout_types_submitted: "1" }

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "documents").value["callout_types"]).to eq([])
    end

    context "with an icon upload" do
      let(:uploader) { instance_double(ImageUploader, store!: true, url: "/uploads/settings/tip.png") }
      let(:image_file) do
        Tempfile.new(["tip_icon", ".png"]).tap do |f|
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

      it "uploads the new file and stores its URL for that row" do
        patch settings_path, params: {
          callout_types_submitted: "1",
          callout_types: [{ type: "tip", title: "Teaching Tip", image: uploaded_file }]
        }

        expect(response).to redirect_to(settings_path)
        expect(uploader).to have_received(:store!)
        expect(Setting.find_by(key: "documents").value["callout_types"]).to eq(
          [{ "type" => "tip", "title" => "Teaching Tip", "image" => "/uploads/settings/tip.png" }]
        )
      end

      it "keeps the existing icon (looked up by type) when the row carries no new upload" do
        Settings.set(:documents, "callout_types" => [
          { "type" => "tip", "title" => "Teaching Tip", "image" => "/uploads/settings/old.png" }
        ])

        patch settings_path, params: {
          callout_types_submitted: "1",
          callout_types: [{ type: "tip", title: "Renamed Tip" }]
        }

        expect(response).to redirect_to(settings_path)
        expect(uploader).not_to have_received(:store!)
        expect(Setting.find_by(key: "documents").value["callout_types"]).to eq(
          [{ "type" => "tip", "title" => "Renamed Tip", "image" => "/uploads/settings/old.png" }]
        )
      end

      it "never persists a client-supplied image URL string" do
        patch settings_path, params: {
          callout_types_submitted: "1",
          callout_types: [{ type: "tip", title: "Teaching Tip", image: "https://evil.example.com/x.png" }]
        }

        expect(response).to redirect_to(settings_path)
        expect(uploader).not_to have_received(:store!)
        expect(Setting.find_by(key: "documents").value["callout_types"]).to eq(
          [{ "type" => "tip", "title" => "Teaching Tip", "image" => nil }]
        )
      end
    end
  end

  describe "admin_view_links form group" do
    before { Settings.set(:admin_view_links, Settings::DEFAULTS[:admin_view_links].deep_stringify_keys) }

    it "renders a list textarea for each key" do
      get settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="admin_view_links[documents]"')
    end

    it "persists an edited list as an array" do
      patch settings_path, params: { admin_view_links: { documents: "/x/:id\n/y/:id" } }

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "admin_view_links").value["documents"]).to eq(["/x/:id", "/y/:id"])
    end

    it "resets to defaults" do
      Settings.set(:admin_view_links, Settings::DEFAULTS[:admin_view_links].deep_stringify_keys.merge("documents" => ["/changed"]))

      delete "#{settings_path}/admin_view_links"

      expect(response).to redirect_to(settings_path)
      expect(Setting.find_by(key: "admin_view_links").value["documents"]).to eq(["/documents/:id"])
    end
  end

  describe "PDF settings form (:pdf)" do
    before { Settings.set(:pdf, Settings::DEFAULTS[:pdf].deep_stringify_keys) }

    describe "GET index" do
      it "renders typed fields for the seeded structure" do
        get settings_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('name="pdf[default][dpi]"')
        expect(response.body).to include('name="pdf[default][margin][top]"')
        expect(response.body).to include("portrait")
      end
    end

    describe "PATCH update" do
      it "persists a valid change with the correct type" do
        patch settings_path, params: { pdf: { default: { dpi: "80" } } }

        expect(response).to redirect_to(settings_path)
        expect(Setting.find_by(key: "pdf").value.dig("default", "dpi")).to eq(80)
      end

      it "does not touch :pdf when the field is absent from the request" do
        patch settings_path, params: { header_bg_color: "#ff0000" }

        expect(Setting.find_by(key: "pdf").value.dig("default", "dpi")).to eq(72)
      end

      it "rejects a non-positive integer and persists nothing" do
        patch settings_path, params: { pdf: { default: { dpi: "-5" } } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(Setting.find_by(key: "pdf").value.dig("default", "dpi")).to eq(72)
        expect(response.body).to include("must be at least 1")
      end

      it "rejects an orientation outside the allowed list" do
        patch settings_path, params: { pdf: { default: { orientation: "sideways" } } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(Setting.find_by(key: "pdf").value.dig("default", "orientation")).to eq("portrait")
      end

      it "rejects a malformed length" do
        patch settings_path, params: { pdf: { default: { margin: { top: "0.5banana" } } } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(Setting.find_by(key: "pdf").value.dig("default", "margin", "top")).to eq("0.5in")
      end

      it "ignores submitted keys that do not already exist (edit-only)" do
        patch settings_path, params: { pdf: { default: { brand_new_key: "x" } } }

        expect(response).to redirect_to(settings_path)
        expect(Setting.find_by(key: "pdf").value["default"]).not_to have_key("brand_new_key")
      end
    end

    describe "DELETE reset" do
      it "restores the group to the shipped defaults" do
        Settings.set(:pdf, Settings::DEFAULTS[:pdf].deep_stringify_keys.tap { |h| h["default"]["dpi"] = 999 })

        delete "#{settings_path}/pdf"

        expect(response).to redirect_to(settings_path)
        expect(Setting.find_by(key: "pdf").value.dig("default", "dpi")).to eq(72)
      end
    end
  end

  describe "PDF renderer setting (:pdf_renderer)" do
    it "renders the renderer select" do
      get settings_path

      expect(response.body).to include('name="default_renderer"')
    end

    it "persists the selected renderer where RendererRegistry reads it" do
      patch settings_path, params: { default_renderer: "prince" }

      expect(response).to redirect_to(settings_path)
      expect(Settings.get(:pdf_renderer)["default_renderer"]).to eq("prince")
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

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 when CarrierWave raises an IntegrityError" do
      allow(uploader).to receive(:store!).and_raise(CarrierWave::IntegrityError, "Invalid file type")

      post "#{settings_path}/upload_image", params: { image: uploaded_file }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("Invalid file type")
    end
  end
end
