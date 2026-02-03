# frozen_string_literal: true

require "rails_helper"

describe "PluginDemo::Tags" do
  let(:admin) { create(:admin) }

  before { login_as admin }

  describe "GET /admin/plugin-demo/tags" do
    it "returns success" do
      get admin_plugin_demo_tags_path

      expect(response).to have_http_status(:ok)
    end

    it "displays all tags" do
      tag = create(:tag, name: "test-tag")

      get admin_plugin_demo_tags_path

      expect(response.body).to include(tag.name)
    end

    it "displays plugin information" do
      get admin_plugin_demo_tags_path

      expect(response.body).to include("Plugin Demo")
      expect(response.body).to include("plugin_demo")
    end
  end

  describe "POST /admin/plugin-demo/tags/create_demo" do
    it "creates demo tag" do
      expect {
        post create_demo_admin_plugin_demo_tags_path
      }.to change(Tag, :count).by(1)
    end

    it "redirects to index with notice" do
      post create_demo_admin_plugin_demo_tags_path

      expect(response).to redirect_to(admin_plugin_demo_tags_path)
      follow_redirect!
      expect(response.body).to include("Demo tag created successfully!")
    end

    context "when demo tag already exists" do
      before { create(:tag, name: PluginDemo::TagService::DEMO_TAG_NAME) }

      it "does not create duplicate" do
        expect {
          post create_demo_admin_plugin_demo_tags_path
        }.not_to change(Tag, :count)
      end
    end
  end
end
