# frozen_string_literal: true

# Plugin Demo
#
# Demonstration plugin showing all plugin system capabilities:
# - Routes
# - Controllers
# - Views
# - Migrations (seed data)
# - Tests
# - Menu registration (standalone and injected)
#
# Access at: /admin/plugin-demo/tags
module PluginDemo
  class << self
    def setup!
      register_menus

      Rails.logger.info "[PluginDemo] Plugin loaded successfully"
    end

    private

    def register_menus
      # Register a standalone menu item
      PluginSystem::MenuRegistry.register(
        :plugin_demo,
        label: "Plugin Demo",
        icon: "bi-puzzle",
        path: :admin_plugin_demo_tags_path,
        position: 500
      )

      # Also add an item to the Resources dropdown menu
      PluginSystem::MenuRegistry.add_to(
        :resources,
        plugin: :plugin_demo,
        label: "Demo Tags",
        icon: "bi-tags",
        path: :admin_plugin_demo_tags_path,
        position: 100,
        divider_before: true
      )
    end
  end
end
