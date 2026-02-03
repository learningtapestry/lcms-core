# frozen_string_literal: true

# Plugin Routes
#
# This file loads routes from all plugins located in lib/plugins/.
# Each plugin can define routes in its config/routes.rb file.
#
# DO NOT EDIT - This file is maintained by Learning Tapestry.
# Plugin routes are loaded automatically from lib/plugins/<plugin_name>/config/routes.rb

plugins_path = Rails.root.join("lib", "plugins")

if plugins_path.exist?
  plugins_path.children.select(&:directory?).sort_by(&:basename).each do |plugin_path|
    routes_file = plugin_path.join("config", "routes.rb")
    next unless routes_file.exist?

    begin
      instance_eval(routes_file.read, routes_file.to_s, 1)
    rescue StandardError => e
      Rails.logger.error "[PluginSystem] Failed to load routes from #{plugin_path.basename}: #{e.message}"
      raise if Rails.env.test?
    end
  end
end
