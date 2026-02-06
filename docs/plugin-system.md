# Plugin System Architecture

This document describes the plugin system architecture for the LCMS Core application. Plugins extend application functionality and are developed together with the main application as git submodules.

## Design Philosophy

- **Simplicity over isolation**: Plugins are part of the application, not isolated gems
- **Unified development**: Clone lcms-core, get all plugins, run all tests together
- **Full access**: Plugins have direct access to all application models, services, and helpers
- **Single test suite**: Plugin tests run as part of the main application test suite
- **Minimal merge conflicts**: Plugin system uses separate files to minimize conflicts for forks

## Directory Structure

```
lcms-core/
  app/
    models/
    controllers/
    ...
  config/
    application.rb              # Single line added to load plugin_paths.rb
    routes.rb                   # Single line added to draw(:plugins)
    plugin_paths.rb             # Plugin autoload configuration (DO NOT EDIT)
    routes/
      plugins.rb                # Plugin routes loader (DO NOT EDIT)
    initializers/
      plugins.rb                # Plugin initialization (DO NOT EDIT)
  lib/
    plugin_system.rb            # Core plugin system module
    plugins/                    # Root directory for all plugins
      .gitkeep
      analytics/                # Example: Git submodule
        lib/
          analytics.rb          # Main entry point
          analytics/
            tracker.rb          # Service classes
        app/
          models/
            analytics/          # Namespaced models
              event.rb
          controllers/
            analytics/          # Namespaced controllers
              events_controller.rb
          views/
            analytics/
        config/
          routes.rb             # Plugin routes (optional)
          locales/              # Plugin translations (optional)
        db/
          migrate/              # Plugin migrations
        spec/
          models/
          services/
          requests/
          factories.rb          # Plugin-specific factories
  spec/
    support/
      plugins.rb                # Loads plugin factories (DO NOT EDIT)
  .rspec                        # Pattern includes plugin specs
```

## How It Works

The plugin system consists of several files that work together:

### Core Files (maintained by Learning Tapestry)

| File                             | Purpose                                    |
|----------------------------------|--------------------------------------------|
| `lib/plugin_system.rb`           | Plugin discovery and loading               |
| `config/plugin_paths.rb`         | Autoload paths, migrations, views, locales |
| `config/routes/plugins.rb`       | Loads routes from all plugins              |
| `config/initializers/plugins.rb` | Initializes plugins after Rails boot       |
| `spec/support/plugins.rb`        | Loads plugin factories and support files   |

### Integration Points (one line each)

Only three files have minimal changes:

**config/application.rb** - loads plugin paths:
```ruby
require_relative "plugin_paths" if File.exist?(File.expand_path("plugin_paths.rb", __dir__))
```

**config/routes.rb** - loads plugin routes:
```ruby
draw(:plugins) if File.exist?(Rails.root.join("config/routes/plugins.rb"))
```

**.rspec** - includes plugin test pattern:
```
--pattern spec/**/*_spec.rb,lib/plugins/**/spec/**/*_spec.rb
```

## Plugin Structure

### Main Entry Point

Each plugin must have `lib/<plugin_name>.rb`:

```ruby
# lib/plugins/analytics/lib/analytics.rb
module Analytics
  class << self
    def setup!
      Rails.logger.info "[Analytics] Plugin loaded"
    end
  end
end
```

The `setup!` method is optional but recommended for initialization logic.

### Models

Plugin models live in `app/models/<plugin_name>/` and inherit from `ApplicationRecord`:

```ruby
# lib/plugins/analytics/app/models/analytics/event.rb
module Analytics
  class Event < ApplicationRecord
    self.table_name = "analytics_events"

    belongs_to :user
    belongs_to :document, optional: true

    validates :event_type, presence: true

    scope :recent, -> { where("created_at > ?", 1.day.ago) }
  end
end
```

### Services

Plugin services live in `lib/<plugin_name>/`:

```ruby
# lib/plugins/analytics/lib/analytics/tracker.rb
module Analytics
  class Tracker
    def track_document_view(user, document)
      Event.create!(
        user: user,
        document: document,
        event_type: "document_view",
        metadata: { title: document.title }
      )
    end
  end
end
```

### Controllers

Plugin controllers inherit from `ApplicationController`:

```ruby
# lib/plugins/analytics/app/controllers/analytics/events_controller.rb
module Analytics
  class EventsController < ApplicationController
    before_action :authenticate_user!

    def index
      @events = Event.where(user: current_user).recent
    end
  end
end
```

### Routes

Plugin routes are defined in `config/routes.rb` within the plugin:

```ruby
# lib/plugins/analytics/config/routes.rb
namespace :analytics do
  resources :events, only: [:index, :create, :show]
  get "dashboard", to: "dashboard#show"
end
```

### Migrations

Use plugin prefix for table names:

```ruby
# lib/plugins/analytics/db/migrate/20240101000000_create_analytics_events.rb
class CreateAnalyticsEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :analytics_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :document, foreign_key: true
      t.string :event_type, null: false
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :analytics_events, :event_type
    add_index :analytics_events, :created_at
  end
end
```

### Views

Plugin views follow Rails conventions:

```erb
<%# lib/plugins/analytics/app/views/analytics/events/index.html.erb %>
<h1>Your Events</h1>

<table>
  <% @events.each do |event| %>
    <tr>
      <td><%= event.event_type %></td>
      <td><%= event.created_at %></td>
    </tr>
  <% end %>
</table>
```

## Testing

### How Plugin Tests Work

1. `.rspec` pattern includes `lib/plugins/**/spec/**/*_spec.rb`
2. `spec/support/plugins.rb` loads factories from all plugins
3. Tests have full access to application models and helpers

### Writing Tests

```ruby
# lib/plugins/analytics/spec/models/analytics/event_spec.rb
require "rails_helper"

describe Analytics::Event, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    it "requires event_type" do
      event = described_class.new(user: user)
      expect(event).not_to be_valid
    end
  end
end
```

### Plugin Factories

```ruby
# lib/plugins/analytics/spec/factories.rb
FactoryBot.define do
  factory :analytics_event, class: "Analytics::Event" do
    association :user
    event_type { "page_view" }
    metadata { {} }
  end
end
```

### Running Tests

```bash
# All tests including plugins
docker compose run --rm test bundle exec rspec

# Only plugin tests
docker compose run --rm test bundle exec rspec lib/plugins/

# Specific plugin
docker compose run --rm test bundle exec rspec lib/plugins/analytics/spec/
```

## Fork Workflow

### Initial Setup

```bash
# Fork on GitHub, then clone
git clone https://github.com/yourorg/lcms-core.git
cd lcms-core

# Add upstream
git remote add upstream https://github.com/learningtapestry/lcms-core.git
```

### Adding Your Plugins

```bash
git submodule add https://github.com/yourorg/your-plugin.git lib/plugins/your_plugin
git add .gitmodules lib/plugins/your_plugin
git commit -s -m "Add your_plugin"
```

### Receiving Updates

```bash
git fetch upstream
git merge upstream/main
# or
git rebase upstream/main
```

### Why Conflicts Are Minimal

| File                       | Your changes | LT changes      | Conflict risk |
|----------------------------|--------------|-----------------|---------------|
| `config/application.rb`    | Your code    | One line at end | Low           |
| `config/routes.rb`         | Your routes  | One line at end | Low           |
| `config/plugin_paths.rb`   | None         | Full file       | None          |
| `config/routes/plugins.rb` | None         | Full file       | None          |
| `lib/plugin_system.rb`     | None         | Full file       | None          |

When merging upstream, accept their version for plugin system files.

## Git Submodule Management

### Adding a Plugin

```bash
git submodule add https://github.com/yourorg/plugin.git lib/plugins/plugin_name
git add .gitmodules lib/plugins/plugin_name
git commit -s -m "Add plugin_name"
```

### Cloning with Plugins

```bash
git clone --recursive https://github.com/learningtapestry/lcms-core.git

# Or after clone
git submodule update --init --recursive
```

### Updating Plugins

```bash
cd lib/plugins/plugin_name
git pull origin main
cd ../../..
git add lib/plugins/plugin_name
git commit -s -m "Update plugin_name"
```

### Removing a Plugin

```bash
git submodule deinit -f lib/plugins/plugin_name
rm -rf .git/modules/lib/plugins/plugin_name
git rm -f lib/plugins/plugin_name
git commit -s -m "Remove plugin_name"
```

## Configuration

### Plugin Configuration

Use environment variables or Rails credentials:

```ruby
# lib/plugins/analytics/lib/analytics.rb
module Analytics
  class << self
    def config
      @config ||= OpenStruct.new(
        api_key: ENV["ANALYTICS_API_KEY"],
        enabled: ENV.fetch("ANALYTICS_ENABLED", "true") == "true"
      )
    end

    def setup!
      return unless config.enabled
      Rails.logger.info "[Analytics] Plugin loaded"
    end
  end
end
```

## Menu Registration

Plugins can add navigation items to the admin menu using `PluginSystem::MenuRegistry`.

### Simple Menu Item

```ruby
# lib/plugins/analytics/lib/analytics.rb
module Analytics
  class << self
    def setup!
      register_menu
    end

    private

    def register_menu
      PluginSystem::MenuRegistry.register(
        :analytics,
        label: "Analytics",
        path: :analytics_dashboard_path,
        icon: "bi-graph-up",      # Optional: Bootstrap icon class
        position: 100             # Optional: sort order (lower = earlier)
      )
    end
  end
end
```

### Dropdown Menu

For plugins with multiple pages, use a dropdown menu:

```ruby
def register_menu
  PluginSystem::MenuRegistry.register(
    :analytics,
    label: "Analytics",
    icon: "bi-graph-up",
    position: 100,
    dropdown: [
      { label: "Dashboard", path: :analytics_dashboard_path, icon: "bi-speedometer" },
      { divider: true },
      { label: "Events", path: :analytics_events_path },
      { label: "Reports", path: :analytics_reports_path }
    ]
  )
end
```

### Adding to Existing Menus

Plugins can add items to built-in dropdown menus (Resources, Users) instead of creating standalone items:

```ruby
def register_menu
  # Add item to the Resources dropdown
  PluginSystem::MenuRegistry.add_to(
    :resources,
    plugin: :analytics,
    label: "Analytics",
    path: :analytics_dashboard_path,
    icon: "bi-graph-up",
    position: 100,
    divider_before: true    # Optional: add divider before this item
  )

  # Add item to the Users dropdown
  PluginSystem::MenuRegistry.add_to(
    :users,
    plugin: :analytics,
    label: "User Activity",
    path: :analytics_user_activity_path,
    position: 200
  )
end
```

Available built-in menus:
- `:resources` - Resources dropdown (Resources, Lessons, Materials, Units, etc.)
- `:users` - Users dropdown (Users, Access Codes)

### Menu Item Options

**For standalone items (`register`):**

| Option     | Type               | Description                                                      |
|------------|--------------------|------------------------------------------------------------------|
| `label`    | String             | Display text (required)                                          |
| `path`     | Symbol/String/Proc | Route helper, path string, or lambda (required for simple items) |
| `icon`     | String             | Bootstrap icon class (e.g., "bi-star")                           |
| `position` | Integer            | Sort order (default: 1000, lower = earlier)                      |
| `dropdown` | Array              | Submenu items for dropdown menus                                 |

**For injected items (`add_to`):**

| Option           | Type               | Description                                     |
|------------------|--------------------|-------------------------------------------------|
| `plugin`         | Symbol             | Plugin identifier (required)                    |
| `label`          | String             | Display text (required)                         |
| `path`           | Symbol/String/Proc | Route helper, path string, or lambda (required) |
| `icon`           | String             | Bootstrap icon class (e.g., "bi-star")          |
| `position`       | Integer            | Sort order within menu (default: 1000)          |
| `divider_before` | Boolean            | Add divider before this item                    |

### Position Guidelines

| Range   | Purpose                               |
|---------|---------------------------------------|
| 0-99    | Core features (reserved for main app) |
| 100-499 | High priority plugins                 |
| 500-899 | Normal plugins                        |
| 900+    | Low priority / utilities              |

## Best Practices

### Naming

- Namespace all code under plugin module
- Prefix tables with plugin name: `analytics_events`
- Use route namespaces: `/analytics/events`

### Code

- Keep plugins focused on one feature
- Avoid inter-plugin dependencies
- Reuse application services

### Testing

- Test real integrations
- Use application factories
- Test edge cases (deleted records, etc.)

### Migrations

- Always make reversible
- Use foreign keys
- Use unique timestamps

## Troubleshooting

### Plugin Not Loading

1. Check `lib/<plugin_name>.rb` exists
2. Check Rails logs for errors
3. Verify directory is in `lib/plugins/`

### Tests Not Found

1. Verify `.rspec` pattern
2. Check files end with `_spec.rb`
3. Ensure `spec/support/plugins.rb` loads

### Routes Not Working

1. Check `config/routes.rb` in plugin
2. Verify syntax is correct
3. Run `rails routes | grep plugin_name`

### Merge Conflicts

1. For plugin system files - accept upstream
2. For integration lines - keep both versions
3. Run tests after resolving
