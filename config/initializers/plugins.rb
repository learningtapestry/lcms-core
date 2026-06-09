# frozen_string_literal: true

# Plugin System Initializer
#
# Loads all plugins after Rails initialization is complete.
#
# DO NOT EDIT - This file is maintained by Learning Tapestry.

# `to_prepare` (not `after_initialize`) so plugin setup! hooks re-run after
# dev-mode code reloads. Plugins use this to re-register renderers and other
# backends whose stores get wiped when Zeitwerk reloads their registry
# modules. Runs once in production.
Rails.application.config.to_prepare do
  PluginSystem.load_all
end
