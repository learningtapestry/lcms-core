# Migration Guide: `lcms.yml` / `lcms-admin.yml` → `Settings` Module

This guide explains how to migrate from the legacy file-based configuration
(`config/lcms.yml` and `config/lcms-admin.yml`) to the new database-backed
configuration accessed through the `Settings` module.

It is aimed at:

- **Forks of `lcms-core`** that customised the YAML files for a host
  application.
- **Plugins** (loaded from `lib/plugins/<name>/`) that previously assumed the
  YAML files were available.
- **Operators** running LCMS deployments and looking after the boot/upgrade
  story.

## TL;DR

| Before | After |
| --- | --- |
| `config/lcms.yml` | `Settings.get(:doc_template, include_defaults: true)` |
| `config/lcms-admin.yml` | `Settings.get(:admin_view_links, include_defaults: true)` + hard-coded `layout "admin"` |
| `DocTemplate.config.dig("metadata", "context").constantize` | `DocTemplate.metadata_context` |
| `DocTemplate.config.dig("metadata", "service").constantize` | `DocTemplate.metadata_service` |
| `DocTemplate.config["queries"]["document"].constantize` | `DocTemplate.document_query` |
| `DocTemplate.config["queries"]["material"].constantize` | `DocTemplate.material_query` |
| `DocTemplate.config["sanitizer"].constantize` | `DocTemplate.sanitizer` |
| `AdminController.settings[:layout]` | (removed — `Admin::AdminController` always renders the `admin` layout) |
| `AdminController.settings.dig(:documents, :index)` | (removed — use `prepend_view_path` instead) |
| `AdminController.settings.dig(:documents, :view_links)` | `Settings.get(:admin_view_links, include_defaults: true)[:documents]` |
| `SETTINGS_DEFAULTS[:appearance]` | `Settings::DEFAULTS[:appearance]` |
| `Setting.get` / `Setting.set` / `Setting.unset` | `Settings.get` / `Settings.set` / `Settings.unset` |

The YAML files are **deleted** in `lcms-core`. Forks that still need to ship
overrides should do so in code (initializer or plugin `setup!`) or by
inserting rows into the `settings` table via a data migration / seed — always
through `Settings.set`.

## Why the change?

`lcms.yml` and `lcms-admin.yml` were created when `lcms-core` was a library
embedded into a separate host application — the host owned the YAML files and
overrode the defaults that ship in the library.

`lcms-core` is now the host itself. Maintaining a parallel YAML override layer
to "act as if it were embedded" added overhead with no payoff:

- Settings lived in two places (Ruby defaults in `DocTemplate::DEFAULTS` /
  `AdminController::DEFAULTS` *and* YAML files that re-declared the same
  defaults).
- The YAML keys were class names as strings, constantized at use sites — error
  prone, hard to grep, and brittle against renames.
- The defaults in `DocTemplate::DEFAULTS` had drifted from the values in
  `lcms.yml` (e.g. `AdminDocumentsQuery` in code vs `Admin::DocumentsQuery` in
  YAML).
- Truly runtime-configurable values (view link templates) could not actually
  be changed at runtime; they required a redeploy.

The new model:

- Code-level defaults live in **one place** (`Settings::DEFAULTS` in
  `lib/settings.rb`).
- All reads and writes go through the `Settings` module, which transparently
  wraps `Rails.cache.fetch` so most calls never hit Postgres.
- `Setting` (the ActiveRecord model) is treated as a private persistence
  detail; callers don't touch it. An `after_commit` callback on the model
  invalidates the relevant cache key if someone does, as a safety net.
- Class names are still resolved by `constantize`, but they're wrapped in
  memoised accessors (`DocTemplate.sanitizer`, `DocTemplate.metadata_context`,
  etc.) — call sites become readable Ruby.

## The two layers

### `Settings` (lib/settings.rb) — the public API

Use this everywhere outside of `app/models/setting.rb` itself:

```ruby
Settings.get(:appearance)                            # raw stored value or nil
Settings.get(:appearance, include_defaults: true)    # merged with Settings::DEFAULTS[:appearance]
Settings.get_multiple([:appearance, :doc_template])  # batch read
Settings.set(:appearance, header_bg_color: "#000")   # write (invalidates cache)
Settings.unset(:appearance)                          # delete row (invalidates cache)
Settings.unset_within(:appearance, :header_logo)     # delete a sub-key
Settings::DEFAULTS[:appearance]                      # raw default constants
```

`Settings.get` wraps `Rails.cache.fetch`, so repeated reads of the same key
within the cache lifetime hit Redis (or whichever cache store is configured),
not Postgres.

### `Setting` (app/models/setting.rb) — internal persistence

The `Setting` ActiveRecord model now contains nothing but:

- the `:key` presence validation, and
- an `after_commit` that calls `Settings.expire_cache_for(key)` whenever a
  row is created, updated, or destroyed.

Callers should not reference this class directly. If you do (for tests
inspecting DB state, mostly), be aware:

- Calling `Setting.update!` / `Setting.destroy` still triggers the cache
  invalidation callback, so the cache stays correct.
- Calling `Setting.find_by(...)` to *read* bypasses the cache — fine for
  asserting "what's in the database?" in a test, but never the right call in
  production code.

## What was removed

The following YAML-only features have **no replacement** in the new model:

1. **`lcms-admin.yml: layout`** — the admin layout is now hard-coded to
   `"admin"`. If a fork needs a different layout for the admin namespace,
   override it in a subclass: `layout "my_admin"` in the relevant controller.

2. **`lcms-admin.yml: <controller>.index`** view-path overrides — the
   `render_customized_view` / `customized_view` helpers and their support code
   in `Admin::AdminController` are gone. Use Rails' standard view-path lookup
   to override admin views from a fork or plugin:

   ```ruby
   # config/initializers/my_views.rb (in a fork)
   # — or, equivalently, in a plugin's setup! method —
   Rails.application.config.to_prepare do
     ActionController::Base.prepend_view_path Rails.root.join("app/views/overrides")
   end
   ```

   Then drop your override at
   `app/views/overrides/admin/documents/index.html.erb` and Rails will find it
   ahead of the built-in `app/views/admin/documents/index.html.erb`.

3. **`lcms.yml: material_presenter`** — this key was unread dead code. It has
   been removed entirely. `MaterialPresenter` is referenced directly by
   classes that need it.

## What stayed configurable

These keys moved into the `:doc_template` setting (one row in the `settings`
table, JSONB value):

| Key | Default |
| --- | --- |
| `contexts` | `%w(default gdoc)` |
| `document_contexts` | `%w(default gdoc)` |
| `material_contexts` | `%w(default gdoc pdf)` |
| `metadata.context` | `"Lt::Lcms::Metadata::Context"` |
| `metadata.service` | `"Lt::Lcms::Metadata::Service"` |
| `queries.document` | `"Admin::DocumentsQuery"` |
| `queries.material` | `"Admin::MaterialsQuery"` |
| `sanitizer` | `"HtmlSanitizer"` |

These moved into the `:admin_view_links` setting:

| Key | Default |
| --- | --- |
| `documents` | `["/documents/:id"]` |
| `materials` | `["/materials/:id"]` |
| `sections` | `["/admin/sections#section_:id"]` |
| `units` | `["/admin/units#unit_:id"]` |

All defaults are stored in `Settings::DEFAULTS` (see `lib/settings.rb`).
`Settings.get(key, include_defaults: true)` does a `deep_merge(stored_value)`
over those defaults, so a stored row only needs to list the keys it actually
overrides.

## Migrating a fork that customised `lcms.yml`

### Step 1 — Find your overrides

Diff your fork's `config/lcms.yml` against the values listed above (or the
old `config/lcms.yml` from before this commit). Anything that matches the
default can be dropped — you do not need to re-state it.

### Step 2 — Choose where to push the overrides

You have three options, in increasing order of "this is configurable at
runtime by an operator":

1. **Initializer (compile-time, code-controlled)** — best when the override is
   coupled to classes only present in your fork.

   ```ruby
   # config/initializers/lcms_overrides.rb
   Rails.application.config.after_initialize do
     # Skip if the DB hasn't been migrated yet (assets:precompile, etc.).
     next unless ActiveRecord::Base.connection.table_exists?("settings")

     Settings.set(:doc_template, {
       sanitizer: "MyFork::Sanitizer",
       metadata: {
         context: "MyFork::Metadata::Context",
         service: "MyFork::Metadata::Service"
       }
     })
     DocTemplate.reload!
   end
   ```

2. **Data migration / seed (one-shot, persisted)** — best when overrides are
   set once at deploy and then live in the database. This is the recommended
   default.

   ```ruby
   # db/migrate/20260601000000_seed_lcms_settings.rb
   class SeedLcmsSettings < ActiveRecord::Migration[8.1]
     def up
       Settings.set(:doc_template, {
         queries: {
           document: "MyFork::DocumentsQuery",
           material: "MyFork::MaterialsQuery"
         }
       })

       Settings.set(:admin_view_links, {
         documents: ["/lessons/:id", "/print/:id"],
         materials: ["/materials/:id"]
       })
     end

     def down
       Settings.unset_within(:doc_template, :queries)
       Settings.unset(:admin_view_links)
     end
   end
   ```

3. **Admin UI** — for `:admin_view_links` we recommend extending
   `app/controllers/admin/settings_controller.rb` and the `SETTINGS` schema
   in `config/initializers/lcms_constants.rb` so operators can edit the link
   templates without a deploy. This is out of scope for the core refactor
   itself; see `Admin::SettingsController` for the existing `:appearance`
   pattern to copy from.

### Step 3 — Delete `config/lcms.yml`

Once the overrides are seeded, delete the file from your fork. `lcms-core` no
longer reads it.

### Step 4 — Update call sites

If your fork has Ruby code that read `DocTemplate.config` directly, replace
it as shown in the TL;DR table at the top of this document. The string-based
`config[...]` / `config.dig(...)` API is gone — use the typed accessors.

Likewise, any code that called `Setting.get` / `Setting.set` / `Setting.unset`
should switch to `Settings.get` / `Settings.set` / `Settings.unset`. The old
class methods on the AR model no longer exist.

## Migrating a plugin

Plugins (those in `lib/plugins/<name>/`) follow the same recipe as forks, but
they typically push their overrides in their `setup!` method instead of an
initializer, so that the plugin remains self-contained.

```ruby
# lib/plugins/my_plugin/lib/my_plugin.rb
module MyPlugin
  def self.setup!
    return unless ActiveRecord::Base.connection.table_exists?("settings")

    existing = Settings.get(:doc_template) || {}
    Settings.set(:doc_template, existing.deep_merge(
      "queries" => { "material" => "MyPlugin::MaterialsQuery" }
    ))
    DocTemplate.reload!
  end
end
```

Notes:

- `Settings.set` accepts string or symbol keys; reads come back symbolised
  when `include_defaults: true` is used (because the deep-merge with defaults
  happens against symbol keys), and as-stored otherwise.
- Always call `DocTemplate.reload!` after mutating `:doc_template`; the
  module memoises constantised classes in-process.
- A plugin that needs to *read* a value should prefer the typed accessors
  (`DocTemplate.material_query`, etc.) over `Settings.get`, so plugins remain
  consistent with core code.

## Caching behaviour

`Settings.get` wraps every read in `Rails.cache.fetch`. The cache key is
`"settings/<key>"` (or `"settings/<key>_with_defaults"` when defaults are
requested), so the two variants don't trample each other.

Invalidation is automatic: the `Setting` ActiveRecord model has an
`after_commit` callback that calls `Settings.expire_cache_for(key)`, deleting
both variants of the key from `Rails.cache` whenever a row is created,
updated, or destroyed. This applies even if some code calls
`Setting.update!` directly bypassing `Settings.set` — the cache stays
consistent.

`DocTemplate.config` adds a *second* tier of in-process memoisation on top of
`Settings.get`, because it constantises class-name strings (`.constantize` is
cheap but not free, and template parsing hits it many times per request).
That memo is **not** automatically invalidated when `Settings.set(:doc_template,
...)` is called from another process — you must call `DocTemplate.reload!`
explicitly. For single-process changes (e.g. seeding from a migration), call
`DocTemplate.reload!` immediately after `Settings.set` in the same process,
or schedule a process restart.

In the test environment, `config.cache_store` is `:null_store`, so caching is
effectively disabled and reads always hit the DB. Specs that need to assert
caching behaviour should swap in `ActiveSupport::Cache::MemoryStore` for the
example — see `spec/lib/settings_spec.rb` for the pattern.

## Boot ordering

`DocTemplate.config` is now lazily loaded — the YAML used to be parsed at
boot time, but the `Settings.get` lookup is deferred until first use. This
avoids the chicken-and-egg problem during `assets:precompile` and other
no-database-available tasks.

If the DB happens to be unreachable when the config is first requested,
`DocTemplate` falls back to `Settings::DEFAULTS[:doc_template]` and the
constantised accessors will still work as long as the referenced classes are
loadable. The same fallback applies to `assets:precompile`.

## Testing notes

- `Settings::DEFAULTS` is now the single source of truth for defaults — tests
  that previously referenced the top-level `SETTINGS_DEFAULTS` constant or
  `Setting::DEFAULTS` should be updated to `Settings::DEFAULTS`.
- Tests that stub settings should stub `Settings`, not `Setting`:
  `allow(Settings).to receive(:get).with(:foo).and_return(...)`.
- For tests that swap in stubbed classes via `:doc_template`, remember to
  call `DocTemplate.reload!` in an `after(:each)` block (or wrap the swap in
  a helper) so subsequent tests get a clean slate.

```ruby
RSpec.configure do |config|
  config.after(:each) { DocTemplate.reload! }
end
```

## Reference: complete file inventory

Files **deleted** by this refactor:

- `config/lcms.yml`
- `config/lcms-admin.yml`

Files **added**:

- `lib/settings.rb` — the `Settings` module (public API, caching, DEFAULTS
  constant).
- `spec/lib/settings_spec.rb` — coverage for the `Settings` API (defaults
  merging, get/set/unset/unset_within/get_multiple, and explicit caching
  behaviour).

Files **modified**:

- `app/models/setting.rb` — stripped down to the `:key` validation and an
  `after_commit` that calls `Settings.expire_cache_for(key)`. All class-level
  helper methods removed.
- `app/controllers/application_controller.rb` — `load_header_settings` now
  calls `Settings.get(:appearance, include_defaults: true)` directly; the
  manual `Rails.cache.fetch` wrapping is gone.
- `app/controllers/admin/admin_controller.rb` — YAML loading and
  `customized_layout` / `customized_view` / `render_customized_view` removed;
  `layout "admin"` hard-coded; `view_links` reads from `Settings.get(...)`.
- `app/controllers/admin/settings_controller.rb` — switched from `Setting.*`
  class methods to `Settings.*`.
- `app/controllers/admin/{documents,materials,sections,units}_controller.rb`
  — `render_customized_view` calls removed.
- `app/controllers/admin/batch_reimports_controller.rb` — switched to
  `DocTemplate.document_query` / `DocTemplate.material_query` and the
  inherited `admin_view_links` helper.
- `config/initializers/lcms_constants.rb` — `SETTINGS_DEFAULTS` removed
  (moved into `Settings::DEFAULTS`).
- `lib/doc_template.rb` — YAML loading removed, lazy `config` plus typed
  accessors added (`sanitizer`, `metadata_context`, `metadata_service`,
  `document_query`, `material_query`, plus the existing `context_types`,
  `document_contexts`, `material_contexts`). Reads through `Settings.get`.
- `app/models/document.rb`,
  `app/queries/admin/materials_query.rb`,
  `app/services/document_build_service.rb`,
  `app/services/section_build_service.rb`,
  `app/services/section_resource_upsert_service.rb`,
  `app/services/unit_resource_upsert_service.rb`,
  `lib/doc_template/template.rb` — switched to the new typed accessors on
  `DocTemplate`.
- `spec/models/setting_spec.rb` — slimmed to AR concerns (validation + the
  `after_commit` callback contract). Behavioural coverage moved to
  `spec/lib/settings_spec.rb`.
- `spec/requests/admin/settings_spec.rb` — `Setting.set` calls switched to
  `Settings.set`. `Setting.find_by` calls left in place — they're inspecting
  DB state from a test, which is a legitimate AR use.
