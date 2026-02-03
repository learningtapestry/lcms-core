# frozen_string_literal: true

# Plugin Demo
#
# Demonstration plugin showing all plugin system capabilities:
# - Routes
# - Controllers
# - Views
# - Migrations (seed data)
# - Tests
#
# Access at: /plugin-demo/tags
module PluginDemo
  class << self
    def setup!
      Rails.logger.info "[PluginDemo] Plugin loaded successfully"
    end
  end
end
