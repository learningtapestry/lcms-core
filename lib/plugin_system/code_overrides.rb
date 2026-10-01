# frozen_string_literal: true

module PluginSystem
  #
  # Plugin code directories are Zeitwerk root directories alongside core's.
  # When two files map to the same constant, Zeitwerk loads the first one and
  # silently ignores the other, so a plugin file such as
  # app/models/document.rb would replace core's Document wholesale (or be
  # ignored itself, depending on directory order).
  #
  # Replacing a core class is never a supported extension (ADR-0004): plugins
  # use the plugin API or a patch in core_patches/. `problems` reports every
  # plugin file whose constant is also defined by another file. A spec fails
  # on any problem and development boot logs a warning for each.
  #
  module CodeOverrides
    Problem = Data.define(:plugin, :constant, :file, :other_files) do
      def message
        "#{plugin} defines #{constant} in #{file}, which is also defined in " \
          "#{other_files.join(', ')}; only one of them is loaded"
      end
    end

    class << self
      # @param cpaths [Hash{String => String}] absolute path => constant path,
      #   as returned by Zeitwerk::Loader#all_expected_cpaths
      # @return [Array<Problem>]
      def problems(cpaths = Rails.autoloaders.main.all_expected_cpaths)
        files = cpaths.select { |path, _| path.end_with?(".rb") }

        files.group_by { |_, constant| constant }.flat_map do |constant, entries|
          paths = entries.map(&:first)
          next [] if paths.size < 2

          paths.filter_map do |path|
            plugin = plugin_name(path)
            next unless plugin

            Problem.new(plugin:, constant:, file: relative(path), other_files: (paths - [path]).map { relative(_1) })
          end
        end
      end

      def warn_about_problems
        problems.each { |problem| PluginSystem.logger.warn "[PluginSystem] #{problem.message}" }
      end

      private

      def plugin_name(path)
        relative = Pathname(path).relative_path_from(PluginSystem::PLUGINS_PATH).to_s
        relative.start_with?("..") ? nil : relative.split("/").first
      end

      def relative(path)
        relative = Pathname(path).relative_path_from(Rails.root).to_s
        relative.start_with?("..") ? path : relative
      end
    end
  end
end
