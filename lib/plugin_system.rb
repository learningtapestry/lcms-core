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

  # Logger for plugin system messages
  #
  # Broadcasts to both stdout (for console visibility) and Rails.logger (for log files).
  # In production and test environments, stdout output is disabled unless PLUGIN_DEBUG=1 is set.
  #
  # @example Usage in plugins
  #   PluginSystem.logger.info "[MyPlugin] Loaded successfully"
  #   PluginSystem.logger.debug "[MyPlugin] Processing data..."
  #
  # @return [ActiveSupport::BroadcastLogger] logger that writes to stdout and log file
  def self.logger
    @logger ||= build_logger
  end

  def self.build_logger
    # Always log to Rails.logger (goes to log file)
    loggers = [Rails.logger]

    # Add stdout logger for console visibility
    # Disabled in production and test environments unless PLUGIN_DEBUG=1 is set
    if stdout_logging_enabled?
      stdout_logger = ActiveSupport::Logger.new($stdout)
      stdout_logger.formatter = proc { |_severity, _time, _progname, msg| "#{msg}\n" }
      stdout_logger.level = Logger::DEBUG
      loggers.unshift(stdout_logger)
    end

    ActiveSupport::BroadcastLogger.new(*loggers)
  end

  def self.stdout_logging_enabled?
    return true if ENV["PLUGIN_DEBUG"].present?
    return false if Rails.env.production? || Rails.env.test?

    true
  end

  private_class_method :build_logger, :stdout_logging_enabled?

  # Menu item positions
  MENU_POSITION_START = 0
  MENU_POSITION_END = 1000

  # Built-in menu identifiers that plugins can extend
  # These correspond to existing dropdown menus in the admin navigation
  MENU_RESOURCES = :resources
  MENU_USERS = :users

  # Menu Registry for plugin navigation items
  #
  # Allows plugins to register menu items that appear in the admin navigation.
  # Supports both standalone items, dropdown menus, and injection into existing menus.
  #
  # @example Register a simple menu item
  #   PluginSystem::MenuRegistry.register(
  #     :my_plugin,
  #     label: "My Plugin",
  #     path: :admin_my_plugin_path,
  #     position: 100
  #   )
  #
  # @example Register a dropdown menu
  #   PluginSystem::MenuRegistry.register(
  #     :analytics,
  #     label: "Analytics",
  #     position: 50,
  #     dropdown: [
  #       { label: "Dashboard", path: :analytics_dashboard_path },
  #       { divider: true },
  #       { label: "Events", path: :analytics_events_path }
  #     ]
  #   )
  #
  # @example Add item to existing Resources menu
  #   PluginSystem::MenuRegistry.add_to(
  #     :resources,
  #     plugin: :my_plugin,
  #     label: "My Items",
  #     path: :admin_my_items_path,
  #     position: 100
  #   )
  module MenuRegistry
    class << self
      # Returns all registered standalone menu items sorted by position
      #
      # @return [Array<Hash>] array of menu item definitions
      def items
        @items ||= []
        @items.sort_by { |item| item[:position] || MENU_POSITION_END }
      end

      # Returns items registered for a specific built-in menu
      #
      # @param menu_id [Symbol] identifier of the built-in menu (:resources, :users)
      # @return [Array<Hash>] array of menu items for this menu, sorted by position
      def items_for(menu_id)
        @menu_items ||= {}
        (@menu_items[menu_id] || []).sort_by { |item| item[:position] || MENU_POSITION_END }
      end

      # Registers a new standalone menu item
      #
      # @param plugin_name [Symbol] unique identifier for the plugin
      # @param options [Hash] menu item options
      # @option options [String] :label display text for the menu item (required)
      # @option options [Symbol, String] :path route helper name or path string (required for simple items)
      # @option options [Integer] :position sort order (default: MENU_POSITION_END)
      # @option options [Array<Hash>] :dropdown submenu items for dropdown menus
      # @option options [String] :icon Bootstrap icon class (e.g., "bi-graph-up")
      def register(plugin_name, **options)
        @items ||= []

        # Remove existing registration for this plugin
        @items.reject! { |item| item[:plugin] == plugin_name }

        @items << options.merge(plugin: plugin_name)

        PluginSystem.logger.debug "[PluginSystem::MenuRegistry] Registered menu: #{options[:label]} (#{plugin_name})"
      end

      # Adds an item to an existing built-in menu
      #
      # @param menu_id [Symbol] identifier of the target menu (:resources, :users)
      # @param options [Hash] menu item options
      # @option options [Symbol] :plugin unique identifier for the plugin (required)
      # @option options [String] :label display text for the menu item (required)
      # @option options [Symbol, String] :path route helper name or path string (required)
      # @option options [Integer] :position sort order within the menu (default: MENU_POSITION_END)
      # @option options [String] :icon Bootstrap icon class (e.g., "bi-graph-up")
      # @option options [Boolean] :divider_before add a divider before this item
      def add_to(menu_id, **options)
        @menu_items ||= {}
        @menu_items[menu_id] ||= []

        plugin_name = options[:plugin]

        # Remove existing registration for this plugin in this menu
        @menu_items[menu_id].reject! { |item| item[:plugin] == plugin_name }

        @menu_items[menu_id] << options

        PluginSystem.logger.debug "[PluginSystem::MenuRegistry] Added to #{menu_id}: #{options[:label]} (#{plugin_name})"
      end

      # Checks if a built-in menu has any plugin items
      #
      # @param menu_id [Symbol] identifier of the built-in menu
      # @return [Boolean]
      def has_items_for?(menu_id)
        items_for(menu_id).any?
      end

      # Clears all registered menu items
      # Primarily used for testing
      def clear!
        @items = []
        @menu_items = {}
      end

      # Checks if any standalone menu items are registered
      #
      # @return [Boolean]
      def any?
        items.any?
      end
    end
  end

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

      logger.info "[PluginSystem] Loaded #{discovered_plugins.size} plugin(s): #{plugin_names.join(', ')}"
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

      logger.debug "[PluginSystem] Loaded: #{plugin_name}"
    rescue StandardError => e
      logger.error "[PluginSystem] Failed to load #{plugin_name}: #{e.message}"
      logger.error e.backtrace&.first(5)&.join("\n")

      # Fail fast in test environment
      raise if Rails.env.test?
    end
  end
end
