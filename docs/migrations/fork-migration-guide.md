# Fork Migration Guide: `lcms.yml` / `lcms-admin.yml` → `Settings`

A practical, hands-on guide for moving an LCMS fork from the legacy YAML
configuration onto the database-backed `Settings` interface that ships in
this version of `lcms-core`.

The audience is the developer maintaining a fork. The aim is a checklist
plus a copy-pasteable seed migration. The worked example below uses a
hypothetical `MyFork` namespace throughout — substitute your fork's
constants and URL patterns wherever you see it.

## What changed

- `config/lcms.yml` and `config/lcms-admin.yml` no longer exist in
  `lcms-core` and are no longer read.
- All settings that were previously YAML-driven now live in the `settings`
  table, accessed through the **`Settings` module**
  (`lib/settings.rb`).
- A handful of YAML keys are gone with **no direct replacement** — they were
  hooks for the embedded `lcms-engine` era and don't fit the new model.
  See [Features removed entirely](#features-removed-entirely) below.

## TL;DR mapping

| Before (YAML) | After (`Settings`) |
| --- | --- |
| `lcms.yml: contexts` | `Settings.set(:doc_template, contexts: [...])` |
| `lcms.yml: document_contexts` | `Settings.set(:doc_template, document_contexts: [...])` |
| `lcms.yml: material_contexts` | `Settings.set(:doc_template, material_contexts: [...])` |
| `lcms.yml: metadata.context` | `Settings.set(:doc_template, metadata: { context: "..." })` |
| `lcms.yml: metadata.service` | `Settings.set(:doc_template, metadata: { service: "..." })` |
| `lcms.yml: queries.document` | `Settings.set(:doc_template, queries: { document: "..." })` |
| `lcms.yml: queries.material` | `Settings.set(:doc_template, queries: { material: "..." })` |
| `lcms.yml: sanitizer` | `Settings.set(:doc_template, sanitizer: "...")` |
| `lcms-admin.yml: <controller>.view_links` | `Settings.set(:admin_view_links, <controller>: [...])` |
| `lcms-admin.yml: layout` | removed — `Admin::AdminController` hard-codes `layout "admin"` |
| `lcms-admin.yml: <controller>.index` | removed — drop the override view into `app/views/admin/<controller>/index.html.erb` (or `prepend_view_path`) |
| `lcms-admin.yml: redirect.*` | removed — route helpers belong in `config/routes.rb` |

`Settings.get(:doc_template, include_defaults: true)` and
`Settings.get(:admin_view_links, include_defaults: true)` always return the
shipped defaults from `Settings::DEFAULTS`, deep-merged with whatever your
fork has stored. So you only need to seed the keys you actually want to
override.

## Migration approach

A four-step checklist:

1. **Identify your overrides.** Diff your fork's `lcms.yml` /
   `lcms-admin.yml` against `Settings::DEFAULTS` in `lib/settings.rb`.
   Anything that matches a default can simply be dropped.
2. **Write one data migration** that seeds your fork's overrides into
   `:doc_template` and `:admin_view_links`. Use the template below — it
   includes a reversible `down` that only undoes what *this* migration set.
3. **Delete `config/lcms.yml` and `config/lcms-admin.yml`** in the same
   release. They are not read by `lcms-core` anymore.
4. **Update Ruby call sites** that referenced the old API:
   - `Setting.get` / `Setting.set` / `Setting.unset` → `Settings.get` / `Settings.set` / `Settings.unset`.
   - `DocTemplate.config["sanitizer"].constantize` → `DocTemplate.sanitizer`.
   - `DocTemplate.config.dig("metadata", "context").constantize` → `DocTemplate.metadata_context`.
   - `DocTemplate.config.dig("metadata", "service").constantize` → `DocTemplate.metadata_service`.
   - `DocTemplate.config["queries"]["document"].constantize` → `DocTemplate.document_query`.
   - `DocTemplate.config["queries"]["material"].constantize` → `DocTemplate.material_query`.
   - `AdminController.settings.dig(:foo, :view_links)` → `Settings.get(:admin_view_links, include_defaults: true)[:foo]`.

## Override semantics

When `Settings.get(key, include_defaults: true)` runs, the stored value is
`deep_merge`-ed onto `Settings::DEFAULTS[key]`. Two kinds of values in the
stored hash are stripped *before* the merge, recursively at every nesting
level:

- `nil`
- **blank strings** — empty (`""`) and whitespace-only (`" "`, `"\n"`, `"\t"`)

Everything else is treated as an intentional override, including:

- empty arrays (`[]`) and empty hashes (`{}`)
- `false`, `0`, non-blank strings, numbers

Practical consequences:

- A stored `metadata: { context: nil }` (typo, partial override) **does not
  poison** `DocTemplate.metadata_context` — the inner `nil` is dropped and
  the default class survives. Same for `metadata: { context: "  " }`.
- A stored `documents: []` **does override** the documents view-link list
  with an empty array — no "View" buttons will render. If you want the
  default back, `Settings.unset_within(:admin_view_links, :documents)`.

## The seed migration template

This is the boilerplate every fork should ship. It uses two helpers
(`merge_into` and `remove_from`) that scope the `down` to the exact
sub-keys this migration sets — so a rollback can't wipe overrides from
sibling migrations or future operator changes.

```ruby
# db/migrate/20260601000000_seed_<fork>_settings.rb
class Seed<Fork>Settings < ActiveRecord::Migration[8.1]
  # Sub-keys this migration owns. The `down` only undoes these.
  DOC_TEMPLATE_OVERRIDES = {
    # "metadata" => %w(context service),
    # "queries"  => %w(document material)
  }.freeze

  DOC_TEMPLATE_TOP_LEVEL = %w().freeze # e.g. %w(sanitizer document_contexts)
  VIEW_LINK_KEYS         = %w().freeze # e.g. %w(documents materials units)

  def up
    merge_into(:doc_template,
      # "sanitizer" => "MyFork::Sanitizer",
      # "metadata"  => { "context" => "MyFork::Metadata::Context",
      #                  "service" => "MyFork::Metadata::Service" },
      # "queries"   => { "document" => "MyFork::Admin::DocumentsQuery",
      #                  "material" => "MyFork::Admin::MaterialsQuery" }
    )

    merge_into(:admin_view_links,
      # "documents" => ["/my_fork/documents/:id"],
      # "materials" => ["/my_fork/materials/:id"]
    )

    DocTemplate.reload!
  end

  def down
    DOC_TEMPLATE_OVERRIDES.each do |branch, sub_keys|
      remove_from(:doc_template, branch, sub_keys, prune_parent: true)
    end
    remove_from(:doc_template, nil, DOC_TEMPLATE_TOP_LEVEL, prune_parent: true)
    remove_from(:admin_view_links, nil, VIEW_LINK_KEYS, prune_parent: true)

    DocTemplate.reload!
  end

  private

  def merge_into(setting_key, overrides)
    return if overrides.empty?

    existing = Settings.get(setting_key) || {}
    Settings.set(setting_key, existing.deep_merge(overrides))
  end

  # Removes the listed sub-keys (under +path+, or at the top level when
  # +path+ is nil), leaving any other overrides under that branch
  # untouched. If +prune_parent+ is true and the branch (or whole setting)
  # becomes empty, it is removed entirely.
  def remove_from(setting_key, path, sub_keys, prune_parent: false)
    return if sub_keys.empty?

    stored = Settings.get(setting_key)
    return unless stored

    if path
      branch = stored[path]
      return unless branch.is_a?(Hash)

      remaining = branch.except(*sub_keys)
      updated = remaining.empty? && prune_parent ? stored.except(path) : stored.merge(path => remaining)
    else
      updated = stored.except(*sub_keys)
    end

    if updated.empty? && prune_parent
      Settings.unset(setting_key)
    else
      Settings.set(setting_key, updated)
    end
  end
end
```

A few notes on this template:

- **Strip leading `::`** from constant strings when seeding. `"::Foo::Bar"`
  and `"Foo::Bar"` are equivalent to `constantize`, but the latter is
  cleaner to grep for in the DB.
- **Call `DocTemplate.reload!`** in both `up` and `down`. `DocTemplate`
  memoises constantised classes per process; without the reload, the
  current process keeps the previous classes until restart.
- **Don't bypass `Settings`** — even if you're tempted to use raw
  ActiveRecord (`Setting.find_or_create_by(...)`), going through
  `Settings.set` keeps the cache consistent through the same code path
  every other caller uses.

## Worked example — a typical fork

A representative fork ships custom metadata/query classes, custom view-link
URLs for the four built-in admin index pages, and one or two fork-specific
admin controllers with their own view links. The walkthrough below uses a
hypothetical `MyFork` namespace.

### `config/lcms.yml` line by line

| Original YAML | What to do |
| --- | --- |
| `contexts: [default, gdoc]` | **Drop if it matches the default.** Otherwise → `:doc_template.contexts`. |
| `document_contexts: [...]` | **Drop if matches default.** Otherwise → `:doc_template.document_contexts`. |
| `material_contexts: [...]` | **Drop if matches default.** Otherwise → `:doc_template.material_contexts`. |
| `metadata.context: '::MyFork::Metadata::Context'` | **Override** → `:doc_template.metadata.context = "MyFork::Metadata::Context"`. |
| `metadata.service: '::MyFork::Metadata::Service'` | **Override** → `:doc_template.metadata.service`. |
| `document_presenter: '::DocumentPresenter'` | **Drop** — see [Features removed entirely](#features-removed-entirely). If your fork defines its own `app/presenters/document_presenter.rb`, Ruby autoload resolves it without help. |
| `material_presenter: '::MaterialPresenter'` | **Drop** — same as above. |
| `sanitizer: '::HtmlSanitizer'` | **Drop if matches default.** Otherwise → `:doc_template.sanitizer`. |
| `queries.document: 'MyFork::Admin::DocumentsQuery'` | **Override** → `:doc_template.queries.document`. |
| `queries.material: 'MyFork::Admin::MaterialsQuery'` | **Override** → `:doc_template.queries.material`. |

### `config/lcms-admin.yml` line by line

| Original YAML | What to do |
| --- | --- |
| `layout: 'admin'` | **Drop** — `Admin::AdminController` hard-codes `layout "admin"` now. If your fork ever needs a different admin layout, subclass `Admin::AdminController`. |
| `redirect.engine.document_path` / `material_path` | **Drop** — never wired up in `lcms-core` itself. Use the Rails route helpers directly in any fork-specific controllers. |
| `<custom_controller>.index: '/my_fork/admin/<custom_controller>/index'` | **Drop** — `<controller>.index` view-path overrides are gone. Put the override file at `app/views/admin/<custom_controller>/index.html.erb`, or `prepend_view_path` if it must live outside `app/views/`. |
| `<custom_controller>.view_links: ['/my_fork/admin/<custom_controller>/']` | **Override** → add `<custom_controller>` to `:admin_view_links`. The key is the controller name, so any controller's view links work — not just the four defaults. |
| `documents.index: '/my_fork/admin/documents/index'` | **Drop** — same view-path-override case; replace with an override view file. |
| `documents.view_links: ['/my_fork/documents/:id']` | **Override** → `:admin_view_links.documents`. |
| `materials.index: '/my_fork/admin/materials/index'` | **Drop** — same as `documents.index`. |
| `materials.view_links: ['/my_fork/materials/:id']` | **Override** → `:admin_view_links.materials`. |
| `units.view_links: ['/my_fork/admin/resources/:id/edit']` | **Override** → `:admin_view_links.units`. |

### The resulting migration

```ruby
# db/migrate/20260601000000_seed_my_fork_settings.rb
class SeedMyForkSettings < ActiveRecord::Migration[8.1]
  DOC_TEMPLATE_OVERRIDES = {
    "metadata" => %w(context service),
    "queries"  => %w(document material)
  }.freeze

  # Includes any custom admin controllers shipped by the fork.
  VIEW_LINK_KEYS = %w(
    documents materials units custom_controller_a custom_controller_b
  ).freeze

  def up
    merge_into(:doc_template,
      "metadata" => {
        "context" => "MyFork::Metadata::Context",
        "service" => "MyFork::Metadata::Service"
      },
      "queries" => {
        "document" => "MyFork::Admin::DocumentsQuery",
        "material" => "MyFork::Admin::MaterialsQuery"
      })

    merge_into(:admin_view_links,
      "documents" => ["/my_fork/documents/:id"],
      "materials" => ["/my_fork/materials/:id"],
      "units"     => ["/my_fork/admin/resources/:id/edit"],
      "custom_controller_a" => ["/my_fork/admin/custom_controller_a/"],
      "custom_controller_b" => ["/my_fork/admin/custom_controller_b/:id"])

    DocTemplate.reload!
  end

  def down
    DOC_TEMPLATE_OVERRIDES.each do |branch, sub_keys|
      remove_from(:doc_template, branch, sub_keys, prune_parent: true)
    end
    remove_from(:admin_view_links, nil, VIEW_LINK_KEYS, prune_parent: true)

    DocTemplate.reload!
  end

  # ...merge_into / remove_from helpers as in the template above...
end
```

After this migration runs in every environment, delete both YAML files
from the fork in the same release.

## Common override patterns

A few patterns that come up across forks. None require code changes in
`lcms-core` — they're all handled by the existing setting schema and merge
semantics.

### Disabling a content format

A fork that doesn't ship a Google-Docs renderer for materials can override
`material_contexts` to a non-default list:

```ruby
merge_into(:doc_template, "material_contexts" => ["default"])
```

If you want to switch off material rendering altogether, store an empty
array — the override semantics treat `[]` as an intentional choice, so
defaults will not leak back in:

```ruby
merge_into(:doc_template, "material_contexts" => [])
```

A non-empty single-element list (e.g. `["none"]`) is also treated as a
deliberate override and never re-merged with the default `[default, gdoc,
pdf]`.

### Many view-link overrides at once

A fork that ships several custom admin controllers can register all their
view links in one go — the key is just `controller_name.to_sym`, so any
controller's links resolve correctly:

```ruby
merge_into(:admin_view_links,
  "documents" => ["/my_fork/documents/:id"],
  "materials" => ["/my_fork/materials/:id"],
  "custom_controller_a" => ["/my_fork/admin/a/"],
  "custom_controller_b" => ["/my_fork/admin/b/:id"]
)
```

Forks are not limited to the four controllers shipped in
`Settings::DEFAULTS[:admin_view_links]`.

### Fork-only settings

If your fork has its own configuration that is *not* a `:doc_template` /
`:admin_view_links` concern (e.g. a list of grades to skip, a feature flag
specific to the fork), don't try to wedge it into a core setting. Use a
**fork-owned key** instead:

```ruby
Settings.set(:my_fork, {
  feature_flag_x: true,
  skip_subjects: %w(art music)
})
```

This is a regular `Settings` row — same caching, same invalidation
behaviour — under a key that's owned by your fork. Add a corresponding
entry to your fork's `SETTINGS` schema (in
`config/initializers/lcms_constants.rb`) if you want it to surface in the
admin settings UI; otherwise leave it as a developer-managed setting.

## Features removed entirely

The following YAML keys had no use site in current `lcms-core` and are
*not* restored by any `Settings` row. If a fork depends on one of these,
plan a code-level change in the same release that runs the seed migration:

- **`bundles`** — was used to wire `BundleGenerator`. `lcms-core` now calls
  `BundleGenerator` directly via constant lookup; if a fork ships a
  different bundler class, override the call site
  (`UnitBundleInteractor`) directly.
- **`document_presenter` / `material_presenter`** — `DocumentPresenter` and
  `MaterialPresenter` are now resolved by Ruby autoload. If a fork defines
  its own class at the same constant name, it wins.
- **`material_form`, `material_parse_job`, `material_preview_job`** —
  hard-coded in `lcms-core`. If a fork must swap these, override the
  calling class.
- **`redirect.engine.*` / `redirect.host.*`** — leftovers from the
  embedded-engine era. Route customisation belongs in `config/routes.rb`.
- **`engine: 'Lcms::Engine::Engine'`** — there is no separate engine to
  delegate to anymore.

These omissions are deliberate: stashing class names in JSONB doesn't help
when the wiring still has to happen in Ruby code.

## Caching, boot, reload

- **`Settings.get` is cached.** Every read goes through
  `Rails.cache.fetch`. Cache invalidation is automatic — the `Setting`
  ActiveRecord model has an `after_commit` that calls
  `Settings.expire_cache_for(key)`, so writes through either `Settings.set`
  or raw AR keep the cache consistent.
- **The `:doc_template` setting has a second tier of in-process memo.**
  `DocTemplate.sanitizer`, `DocTemplate.metadata_context`, etc. all
  constantise the stored class names and memoise the result. After
  mutating `:doc_template` in a migration or seed, call
  **`DocTemplate.reload!`** in the same process so the new classes take
  effect immediately. Other processes will pick up the change at their
  next boot.
- **`DEFAULTS` is fingerprinted into the cache key for `include_defaults:
  true`.** A deploy that ships a different `Settings::DEFAULTS` constant
  bumps the fingerprint, so stale merged values from the previous deploy
  are never served — even if Redis survives the deploy and no `Setting`
  row has changed.
- **`Settings.get` is safe during `assets:precompile`** and similar
  no-database tasks: `DocTemplate.config` rescues
  `ActiveRecord::StatementInvalid`, `NoDatabaseError`, and
  `ConnectionNotEstablished` and falls back to
  `Settings::DEFAULTS[:doc_template]`.

## Plugin authors

Plugins (those under `lib/plugins/<name>/`) follow the same recipe as
forks but typically push overrides in their `setup!` method instead of a
migration:

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

Plugins should read through the typed accessors
(`DocTemplate.material_query`, etc.) rather than
`Settings.get(:doc_template)` directly, so they stay consistent with
`lcms-core`'s call sites.
