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

# Report plugin views that replace undeclared core views or override a
# declared template core no longer ships (PluginSystem::ViewOverrides), and
# plugin files that define a constant core already defines
# (PluginSystem::CodeOverrides). Specs enforce the same checks in CI.
Rails.application.config.after_initialize do
  if Rails.env.development?
    PluginSystem::ViewOverrides.warn_about_problems
    PluginSystem::CodeOverrides.warn_about_problems
  end
end
