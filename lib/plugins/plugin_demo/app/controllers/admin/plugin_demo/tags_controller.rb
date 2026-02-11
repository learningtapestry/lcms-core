# frozen_string_literal: true

module Admin
  module PluginDemo
    # Controller demonstrating plugin capabilities
    #
    # Shows all tags including the demo tag created by this plugin.
    class TagsController < AdminController
      before_action :set_tag_service

      # GET /plugin-demo/tags
      def index
        @tags = @tag_service.all_tags
        @demo_tag = @tag_service.demo_tag
        @demo_tag_exists = @tag_service.demo_tag_exists?
      end

      # POST /plugin-demo/tags/create_demo
      def create_demo
        @tag_service.ensure_demo_tag_exists!
        redirect_to admin_plugin_demo_tags_path, notice: "Demo tag created successfully!"
      end

      private

      def set_tag_service
        @tag_service = ::PluginDemo::TagService.new
      end
    end
  end
end
