source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
# NOTE: Temporarily disabled in favor of Sprockets (required by sass-rails from lcms-engine)
# Will migrate to Propshaft in Phase 6 after migrating assets
# gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # RSpec testing framework
  gem "rspec-rails", "~> 7.1"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

# ============================================================================
# Dependencies migrated from lcms-engine gem
# ============================================================================

# Authentication & Authorization
gem "devise", "~> 4.9"

# Background Jobs & Queue
gem "redis", "~> 5.4"
gem "hiredis", "~> 0.6.3"
gem "resque"
gem "resque-scheduler", "~> 4.10"
gem "activejob-retry", "~> 0.6.3"
gem "concurrent-ruby", "~> 1.3"

# Search & Full-text
gem "elasticsearch-model", "~> 8.0"
gem "elasticsearch-rails", "~> 8.0"
gem "elasticsearch-dsl", "~> 0.1.9"
gem "elasticsearch-persistence", "~> 8.0"
gem "pg_search", "~> 2.3", ">= 2.3.2"

# File Upload & Storage
gem "carrierwave", "~> 3.0"
gem "aws-sdk-s3", "~> 1"
gem "aws-sdk-rails", "~> 4.0"
gem "fog-aws", "~> 3.5", ">= 3.5.2"
gem "mini_magick", "~> 5.3"

# Google APIs Integration
gem "google-apis-drive_v3", "~> 0.66"
gem "google-apis-script_v1", "~> 0.28"
gem "lt-google-api", "~> 0.4"
gem "lt-lcms", "~> 0.7"

# Tagging & Trees
gem "acts-as-taggable-on", "~> 13.0"
gem "closure_tree", "~> 7.1"
gem "acts_as_list", "~> 1.0"

# Forms & UI
gem "simple_form", "~> 5.3"
gem "ckeditor", "~> 5.1", ">= 5.1.3"
gem "will_paginate", "~> 4.0"
gem "will_paginate-bootstrap-style", "~> 0.3"
gem "ransack", "~> 4.2"

# API & Serialization
gem "active_model_serializers", "~> 0.10.10"
gem "oj", "~> 3.16"
gem "oj_mimic_json", "~> 1.0", ">= 1.0.1"

# Document Processing
gem "combine_pdf", "~> 1.0"
gem "rubyzip", "~> 2.3"
gem "nokogiri", "~> 1.16"
gem "sanitize", "~> 6.1"
gem "wicked_pdf", "~> 2.1"
gem "wkhtmltopdf-binary", "~> 0.12.6"

# HTTP & External APIs
gem "httparty", "~> 0.22"
gem "rest-client", "~> 2.1", ">= 2.1.0"
gem "retriable", "~> 3.1"

# Assets & Styles
gem "autoprefixer-rails", "~> 10.0"
gem "sass-rails", "~> 6.0"
gem "sprockets-rails", "~> 3.5"

# Utilities
gem "validate_url", "~> 1.0", ">= 1.0.8"
gem "virtus", "~> 1.0", ">= 1.0.5"
gem "ruby-progressbar", "~> 1.13"
gem "with_advisory_lock", "~> 5.0"

# Monitoring & Performance
gem "airbrake", "~> 13.0"
gem "rack-mini-profiler", "~> 4.0", require: false
gem "rack", "~> 3.0"
