require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module App
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # =========================================================================
    # Configuration migrated from lcms-engine
    # =========================================================================

    # Redis configuration
    config.redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379'))

    # ActiveJob queue adapter (using Resque)
    config.active_job.queue_adapter = :resque

    # Autoload paths
    config.autoload_paths += [
      config.root.join('app', 'jobs', 'concerns')
    ]

    # i18n load path
    config.i18n.load_path += Dir[config.root.join('config', 'locales', '**', '*.yml')]

    # Assets paths for external fonts
    config.assets.paths << config.root.join('node_modules/bootstrap-icons/font')
    config.assets.paths << config.root.join('node_modules/@fortawesome/fontawesome-free/webfonts')

    # Assets precompilation
    config.assets.precompile += %w(ckeditor/config.js)

    # Generators configuration
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.factory_bot dir: 'spec/factories'
    end
  end
end
