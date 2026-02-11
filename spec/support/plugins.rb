# frozen_string_literal: true

# Plugin Test Support
#
# This file loads test support files and factories from all plugins.
# It is automatically loaded by spec/rails_helper.rb.
#
# DO NOT EDIT - This file is maintained by Learning Tapestry.

plugins_path = Rails.root.join("lib", "plugins")

if plugins_path.exist?
  plugins_path.children.select(&:directory?).sort_by(&:basename).each do |plugin_path|
    # Load plugin factories
    factories_file = plugin_path.join("spec", "factories.rb")
    require factories_file.to_s if factories_file.exist?

    # Load factory files from factories/ directory
    factories_dir = plugin_path.join("spec", "factories")
    if factories_dir.exist?
      Dir[factories_dir.join("**", "*.rb")].sort.each { |f| require f }
    end

    # Load plugin support files
    support_dir = plugin_path.join("spec", "support")
    if support_dir.exist?
      Dir[support_dir.join("**", "*.rb")].sort.each { |f| require f }
    end
  end
end

# Configure RSpec to include plugin spec paths
RSpec.configure do |config|
  # Add plugin spec directories to the pattern
  plugin_spec_dirs = plugins_path.children.select(&:directory?).map do |plugin_path|
    plugin_path.join("spec", "**", "*_spec.rb").to_s
  end

  # This is informational - the actual pattern is set in .rspec or command line
  Rails.logger.debug "[PluginSystem] Plugin spec patterns: #{plugin_spec_dirs.join(', ')}" if plugin_spec_dirs.any?
end if plugins_path.exist?
