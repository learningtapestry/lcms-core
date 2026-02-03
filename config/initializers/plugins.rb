# frozen_string_literal: true

# Plugin System Initializer
#
# Loads all plugins after Rails initialization is complete.
#
# DO NOT EDIT - This file is maintained by Learning Tapestry.

require_relative "../../lib/plugin_system"

Rails.application.config.after_initialize do
  PluginSystem.load_all
end
