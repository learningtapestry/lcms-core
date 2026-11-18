# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Units", type: :request do
  let(:admin) { create(:admin) }
  let(:unit) { create(:resource, :unit) }
  let(:cover_url) { "https://bucket.s3.us-east-1.amazonaws.com/uploads/covers/abc123.jpg" }

  before do
    login_as(admin, scope: :user)
    allow(UnitCoverUploader).to receive(:bucket_host).and_return("bucket.s3.us-east-1.amazonaws.com")
  end

  describe "authorization" do
    let(:user) { create(:user) }

    before do
      logout
      login_as(user, scope: :user)
    end

    it "redirects a non-admin away from the edit page" do
      get edit_admin_unit_path(unit)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /admin/units/:id/edit" do
    it "renders the cover form" do
      get edit_admin_unit_path(unit)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("unit[cover_image_credit]")
    end

    it "shows the imported unit metadata and source, but not the cover keys" do
      unit.update!(
        links: { "source" => { "gdoc" => { "name" => "Unit 1 Metadata", "url" => "https://docs.google.com/document/d/abc",
                                           "timestamp" => 1_700_000_000 } } },
        metadata: unit.metadata.merge("unit_topic" => "Fractions", "material_ids" => %w(m1 m2),
                                      "description" => "<p>About <b>fractions</b></p>",
                                      UnitPresenter::COVER_CREDIT_KEY => "iStock.com / Hakase_")
      )

      get edit_admin_unit_path(unit)

      body = response.body
      expect(body).to include("Imported metadata", "unit_topic", "Fractions", "m1, m2", "<b>fractions</b>")
      expect(body).to include("Unit 1 Metadata", "https://docs.google.com/document/d/abc")
      expect(body).not_to include("<code>#{UnitPresenter::COVER_CREDIT_KEY}</code>")
    end
  end

  describe "PATCH /admin/units/:id" do
    it "stores the cover image and credit in the unit metadata" do
      patch admin_unit_path(unit), params: {
        unit: { cover_image_url: cover_url, cover_image_credit: " iStock.com / Hakase_ " }
      }

      expect(response).to redirect_to(admin_units_path(anchor: "unit_#{unit.id}", query: {}))
      expect(unit.reload.metadata).to include(
        UnitPresenter::COVER_IMAGE_KEY => cover_url,
        UnitPresenter::COVER_CREDIT_KEY => "iStock.com / Hakase_"
      )
    end

    it "keeps the imported unit metadata" do
      patch admin_unit_path(unit), params: { unit: { cover_image_url: cover_url } }

      expect(unit.reload.metadata).to include("subject" => "math", "unit" => "unit 1")
    end

    it "accepts a local upload path" do
      patch admin_unit_path(unit), params: { unit: { cover_image_url: "/uploads/covers/abc123.jpg" } }

      expect(unit.reload.metadata[UnitPresenter::COVER_IMAGE_KEY]).to eq "/uploads/covers/abc123.jpg"
    end

    [
      "javascript:alert(1)",
      "file:///etc/passwd",
      "https://evil.example.com/other/path.jpg",
      "http://10.0.0.5:8080/uploads/covers/abc123.jpg",
      "https://bucket.s3.us-east-1.amazonaws.com/uploads/settings/brandmark.png",
      "/uploads/settings/brandmark.png",
      "/uploads/covers/../../config/secrets.yml",
      "/etc/passwd"
    ].each do |bad_url|
      it "rejects #{bad_url.inspect}" do
        patch admin_unit_path(unit), params: { unit: { cover_image_url: bad_url } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(unit.reload.metadata).not_to have_key(UnitPresenter::COVER_IMAGE_KEY)
      end
    end

    context "with an existing cover image" do
      let(:old_url) { "https://bucket.s3.us-east-1.amazonaws.com/uploads/settings/old.jpg" }

      before do
        unit.update!(metadata: unit.metadata.merge(UnitPresenter::COVER_IMAGE_KEY => old_url))
        allow(UnitCoverUploader).to receive(:delete_by_url)
      end

      it "removes the cover and deletes the stored image when asked" do
        patch admin_unit_path(unit), params: { unit: { cover_image_url: old_url, remove_cover_image: "1" } }

        expect(unit.reload.metadata).not_to have_key(UnitPresenter::COVER_IMAGE_KEY)
        expect(UnitCoverUploader).to have_received(:delete_by_url).with(old_url)
      end

      it "keeps a cover saved before covers had their own directory" do
        patch admin_unit_path(unit), params: { unit: { cover_image_url: old_url, cover_image_credit: "New" } }

        expect(response).to redirect_to(admin_units_path(anchor: "unit_#{unit.id}", query: {}))
      end

      it "keeps the stored image when only the credit changes" do
        patch admin_unit_path(unit), params: { unit: { cover_image_url: old_url, cover_image_credit: "New" } }

        expect(unit.reload.metadata[UnitPresenter::COVER_IMAGE_KEY]).to eq old_url
        expect(UnitCoverUploader).not_to have_received(:delete_by_url)
      end
    end
  end

  describe "GET /admin/units/:id/digital_access" do
    it "queues the Teacher Bundle for Digital Access and shows its status page" do
      allow(DigitalAccessBundleJob).to receive(:queued_or_running_job_for).and_return(nil)
      allow(DigitalAccessBundleJob).to receive(:perform_later)
        .with(unit.id, { with_dependants: true }).and_return(instance_double(DigitalAccessBundleJob, job_id: "jid-1"))

      get digital_access_admin_unit_path(unit)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("jid-1", "/admin/units/digital_access_status")
    end
  end

  describe "GET /admin/units/:id/full_download" do
    it "queues the Full Unit Content for Download and shows its status page" do
      allow(FullDownloadBundleJob).to receive(:queued_or_running_job_for).and_return(nil)
      allow(FullDownloadBundleJob).to receive(:perform_later)
        .with(unit.id, { with_dependants: true }).and_return(instance_double(FullDownloadBundleJob, job_id: "jid-2"))

      get full_download_admin_unit_path(unit)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("jid-2", "/admin/units/full_download_status", "Full Unit Content for Download")
    end
  end

  describe "GET /admin/units" do
    it "offers the Teacher Bundle for Digital Access" do
      unit

      get admin_units_path

      expect(response.body).to include("Teacher Bundle for Digital Access", digital_access_admin_unit_path(unit))
    end

    it "links the Teacher Bundle to Print PDF and Google Doc, not their folders" do
      unit.update!(links: { "unit_bundle" => {
        "pdf" => { "url" => "https://s3.test/k_u1/k_u1.pdf", "folder_url" => "https://s3.test/k_u1" },
        "gdoc" => { "url" => "https://drive.google.com/open?id=FOLDER1", "document_url" => "https://drive.google.com/open?id=DOC1" }
      } })

      get admin_units_path

      expect(response.body).to include("Teacher Bundle to Print", "https://s3.test/k_u1/k_u1.pdf",
                                       "https://drive.google.com/open?id=DOC1")
      expect(response.body).not_to include("open?id=FOLDER1")
    end

    it "warns about Non-LCMS files the last bundle left out" do
      unit.update!(links: { "full_download" => { "zip" => {
        "url" => "https://s3.test/k_u1.zip",
        "skipped" => [{ "folder" => "Course/Unit 1", "file" => "Quiz <b>", "reason" => "Google form files can't be downloaded" }]
      } } })

      get admin_units_path

      expect(response.body).to include("1 file skipped", "Course/Unit 1/Quiz &lt;b&gt;: Google form files can&#39;t be downloaded")
    end

    it "offers the Full Unit Content for Download and links a generated zip" do
      unit.update!(links: { "full_download" => { "zip" => { "url" => "https://s3.test/k_u1.zip" } } })

      get admin_units_path

      expect(response.body).to include("Full Unit Content for Download", full_download_admin_unit_path(unit),
                                       "https://s3.test/k_u1.zip")
    end
  end

  describe "POST /admin/units/:id/upload_cover" do
    let(:uploader) { instance_double(UnitCoverUploader, store!: true, url: cover_url) }
    let(:image_file) do
      Tempfile.new(["cover", ".png"]).tap do |f|
        f.binmode
        f.write("\x89PNG\r\n\x1a\n")
        f.rewind
      end
    end
    let(:uploaded_file) { Rack::Test::UploadedFile.new(image_file.path, "image/png") }

    before { allow(UnitCoverUploader).to receive(:new).and_return(uploader) }

    after { image_file.close! }

    it "stores the image and returns its URL" do
      post upload_cover_admin_unit_path(unit), params: { image: uploaded_file }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["url"]).to eq cover_url
    end

    it "returns 422 when no file is provided" do
      post upload_cover_admin_unit_path(unit), params: { image: "not_a_file" }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 when the upload is rejected" do
      allow(uploader).to receive(:store!).and_raise(CarrierWave::IntegrityError, "Invalid file type")

      post upload_cover_admin_unit_path(unit), params: { image: uploaded_file }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"]).to include("Invalid file type")
    end
  end

  describe "POST /admin/units/:id/reimport" do
    let(:source_url) { "https://docs.google.com/document/d/abc123/edit" }

    before { allow(UnitParseJob).to receive(:perform_later).and_return(instance_double(UnitParseJob, job_id: "job-1")) }

    context "when the unit has a source document" do
      before { unit.update!(links: { "source" => { "gdoc" => { "url" => source_url } } }) }

      it "queues a parse job for the source document and shows the import status page" do
        post reimport_admin_unit_path(unit)

        expect(UnitParseJob).to have_received(:perform_later).with(source_url)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Import Units")
      end

      it "shows an enabled Reimport button on the edit page" do
        get edit_admin_unit_path(unit)

        expect(response.body).to include(reimport_admin_unit_path(unit))
      end
    end

    context "when the unit has no source document" do
      it "redirects back to the edit page without queueing a job" do
        post reimport_admin_unit_path(unit)

        expect(UnitParseJob).not_to have_received(:perform_later)
        expect(response).to redirect_to(edit_admin_unit_path(unit))
        expect(flash[:alert]).to eq(I18n.t("admin.shared.reimport.no_source"))
      end

      it "shows a disabled Reimport button on the edit page" do
        get edit_admin_unit_path(unit)

        expect(response.body).not_to include(reimport_admin_unit_path(unit))
        expect(response.body).to include(I18n.t("admin.shared.reimport.no_source"))
      end
    end
  end
end
