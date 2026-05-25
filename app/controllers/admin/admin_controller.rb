# frozen_string_literal: true

module Admin
  class AdminController < ApplicationController
    RE_GOOGLE_FOLDER = %r{/drive/(.*/)?folders/}

    layout "admin"

    before_action :authenticate_admin!

    private

    def authenticate_admin!
      redirect_to root_path, alert: "Access denied" unless current_user&.admin?
    end

    #
    # @return [Array<String>]
    #
    def view_links
      Array.wrap(admin_view_links[controller_name.to_sym])
    end

    def admin_view_links
      @admin_view_links ||= Settings.get(:admin_view_links, include_defaults: true) || {}
    end
  end
end
