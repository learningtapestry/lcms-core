# frozen_string_literal: true

# Plugin Paths Configuration
#
# This file configures autoload paths for plugins located in lib/plugins/.
# It is automatically loaded by config/application.rb.
#
# DO NOT EDIT - This file is maintained by Learning Tapestry.
# Customizations should be made in individual plugins.

plugins_path = Rails.root.join("lib", "plugins")
plugin_view_paths = []

if plugins_path.exist?
  plugins_path.children.select(&:directory?).sort.each do |plugin_path|
    # Add lib/ to autoload and eager load paths
    lib_path = plugin_path.join("lib")
    if lib_path.exist?
      Rails.application.config.autoload_paths << lib_path
      Rails.application.config.eager_load_paths << lib_path
    end

    # Add every app/ subdirectory, the same way Rails does for the app and for
    # engines: all of them except the ones that hold no Ruby constants.
    app_path = plugin_path.join("app")
    if app_path.exist?
      app_path.children.select(&:directory?).each do |subdir_path|
        next if %w(assets javascript views).include?(subdir_path.basename.to_s)

        Rails.application.config.autoload_paths << subdir_path
        Rails.application.config.eager_load_paths << subdir_path
      end
    end

    # Add migrations path
    migrations_path = plugin_path.join("db", "migrate")
    Rails.application.config.paths["db/migrate"] << migrations_path if migrations_path.exist?

    # Collect views path (prepended below)
    views_path = plugin_path.join("app", "views")
    plugin_view_paths << views_path if views_path.exist?

    # Add locales path
    locales_path = plugin_path.join("config", "locales")
    if locales_path.exist?
      Rails.application.config.i18n.load_path += Dir[locales_path.join("**", "*.{rb,yml}")]
    end
  end
end

# Plugin views go before core views, so a plugin can override the templates
# declared in PluginSystem::ViewOverrides::DECLARED. On a conflict between
# plugins, the first in alphabetical order wins.
Rails.application.config.paths["app/views"].unshift(*plugin_view_paths.map(&:to_s))
