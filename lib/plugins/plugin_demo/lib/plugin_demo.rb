# frozen_string_literal: true

# Plugin Demo
#
# Demonstration plugin showing all plugin system capabilities:
# - Routes
# - Controllers
# - Views
# - Models (PluginDemo::Tag, PluginDemo::Tagging)
# - Migrations (creates and owns `tags` and `taggings` tables)
# - Tests
# - Menu registration (standalone and injected)
# - Model extension (adds acts_as_taggable_on to Resource)
#
# This plugin owns the `tags` and `taggings` tables via the acts-as-taggable-on gem.
# If another plugin needs tagging functionality, it should declare plugin_demo
# as a dependency rather than adding acts-as-taggable-on independently.
#
# Access at: /admin/plugin-demo/tags
module PluginDemo
  class << self
    def setup!
      extend_models
      register_menus

      PluginSystem.logger.info "[PluginDemo] Plugin loaded successfully"
    end

    private

    # Adds acts_as_taggable_on :tags to Resource so that resources can be tagged
    def extend_models
      Resource.class_eval do
        acts_as_taggable_on :tags
      end
    end

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
