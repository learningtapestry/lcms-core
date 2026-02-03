# frozen_string_literal: true

# Plugin System for LCMS Core
#
# This module handles automatic discovery and loading of plugins located in lib/plugins/.
# Plugins are git submodules that extend application functionality while maintaining
# separate version control.
#
# @see docs/plugin-system.md for full documentation
module PluginSystem
  PLUGINS_PATH = Rails.root.join("lib", "plugins")

  class << self
    # Returns list of discovered plugin directories
    #
    # A valid plugin must have a lib/ subdirectory containing the main plugin file.
    #
    # @return [Array<Pathname>] array of plugin directory paths
    def discovered_plugins
      @discovered_plugins ||= begin
        return [] unless PLUGINS_PATH.exist?

        PLUGINS_PATH.children.select do |dir|
          dir.directory? && dir.join("lib").exist?
        end.sort_by(&:basename)
      end
    end

    # Returns list of plugin names
    #
    # @return [Array<String>] array of plugin names
    def plugin_names
      discovered_plugins.map { |p| p.basename.to_s }
    end

    # Loads all discovered plugins
    #
    # Called during Rails initialization to set up plugins.
    # In test environment, raises errors immediately for faster debugging.
    def load_all
      return if discovered_plugins.empty?

      discovered_plugins.each do |plugin_path|
        load_plugin(plugin_path)
      end

      Rails.logger.info "[PluginSystem] Loaded #{discovered_plugins.size} plugin(s): #{plugin_names.join(', ')}"
    end

    # Checks if any plugins are available
    #
    # @return [Boolean] true if plugins directory exists and contains plugins
    def plugins_available?
      discovered_plugins.any?
    end

    private

    def load_plugin(plugin_path)
      plugin_name = plugin_path.basename.to_s

      # Use Zeitwerk autoloading - just constantize the module name
      # The lib path is already in autoload_paths via config/plugin_paths.rb
      plugin_module = plugin_name.camelize.constantize

      # Call setup hook if defined
      plugin_module.setup! if plugin_module.respond_to?(:setup!)

      Rails.logger.debug "[PluginSystem] Loaded: #{plugin_name}"
    rescue StandardError => e
      Rails.logger.error "[PluginSystem] Failed to load #{plugin_name}: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      # Fail fast in test environment
      raise if Rails.env.test?
    end
  end
end
