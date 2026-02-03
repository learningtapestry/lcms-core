# frozen_string_literal: true

# Plugin Paths Configuration
#
# This file configures autoload paths for plugins located in lib/plugins/.
# It is automatically loaded by config/application.rb.
#
# DO NOT EDIT - This file is maintained by Learning Tapestry.
# Customizations should be made in individual plugins.

plugins_path = Rails.root.join("lib", "plugins")

if plugins_path.exist?
  plugins_path.children.select(&:directory?).each do |plugin_path|
    # Add lib/ to autoload paths
    lib_path = plugin_path.join("lib")
    Rails.application.config.autoload_paths << lib_path if lib_path.exist?

    # Add app/ subdirectories to autoload paths
    app_path = plugin_path.join("app")
    if app_path.exist?
      %w(models controllers services jobs helpers mailers).each do |subdir|
        subdir_path = app_path.join(subdir)
        Rails.application.config.autoload_paths << subdir_path if subdir_path.exist?
      end
    end

    # Add migrations path
    migrations_path = plugin_path.join("db", "migrate")
    Rails.application.config.paths["db/migrate"] << migrations_path if migrations_path.exist?

    # Add views path
    views_path = plugin_path.join("app", "views")
    Rails.application.config.paths["app/views"] << views_path if views_path.exist?

    # Add locales path
    locales_path = plugin_path.join("config", "locales")
    if locales_path.exist?
      Rails.application.config.i18n.load_path += Dir[locales_path.join("**", "*.{rb,yml}")]
    end
  end
end
