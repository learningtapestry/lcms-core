# frozen_string_literal: true

module PluginSystem
  #
  # Plugin view paths are prepended (config/plugin_paths.rb), so a plugin view
  # at the same path as a core view replaces it. Only the templates in DECLARED
  # are part of the plugin API (docs/plugin-api.md §6); overriding any other
  # core view is an unsupported patch.
  #
  # `problems` reports the two ways an override goes wrong:
  #
  #   :undeclared - the plugin replaces a core view that is not in DECLARED
  #   :orphaned   - the plugin overrides a DECLARED template that core no
  #                 longer ships, so the override silently stopped applying
  #
  # A spec fails on any problem (so client CI catches it) and development boot
  # logs a warning for each.
  #
  module ViewOverrides
    # Logical template names: path under app/views, no format/handler
    # extensions, partials keep their leading underscore.
    DECLARED = %w(
      documents/_content
      documents/pdf/_header
      documents/pdf/_footer
      documents/gdoc/_header
      documents/gdoc/_content
      materials/pdf/_header
      materials/pdf/_footer
      materials/gdoc/_header
      layouts/pdf
      layouts/gdoc
    ).freeze

    Problem = Data.define(:plugin, :template, :kind) do
      def message
        case kind
        when :undeclared
          "#{plugin} overrides core view #{template}, which is not a declared override (docs/plugin-api.md §6)"
        when :orphaned
          "#{plugin} overrides #{template}, but core no longer ships that template, so the override is unused"
        end
      end
    end

    class << self
      # @param plugin_paths [Array<Pathname>] plugin directories to check
      # @return [Array<Problem>]
      def problems(plugin_paths = PluginSystem.discovered_plugins)
        core = templates_in(Rails.root.join("app", "views"))

        plugin_paths.flat_map do |plugin_path|
          plugin = plugin_path.basename.to_s
          templates_in(plugin_path.join("app", "views")).filter_map do |template|
            if DECLARED.include?(template)
              Problem.new(plugin:, template:, kind: :orphaned) unless core.include?(template)
            elsif core.include?(template)
              Problem.new(plugin:, template:, kind: :undeclared)
            end
          end
        end
      end

      def warn_about_problems
        problems.each { |problem| PluginSystem.logger.warn "[PluginSystem] #{problem.message}" }
      end

      # @return [Set<String>] logical names of the templates under views_path
      def templates_in(views_path)
        return Set.new unless views_path.exist?

        Dir.glob("**/*", base: views_path).filter_map do |file|
          next unless views_path.join(file).file?

          dir = File.dirname(file)
          name = File.basename(file).split(".", 2).first
          next if name.empty?

          dir == "." ? name : File.join(dir, name)
        end.to_set
      end
    end
  end
end
