# Plugin API (draft)

> **Status: Draft v0 — for discussion.** Implements the policy in
> [ADR-0004](adr/0004-stable-plugin-api.md) within the distribution model of
> [ADR-0003](adr/0003-client-distribution-and-release-model.md).
> Nothing in this document is a stability promise until the draft is accepted
> and each extension point is marked **Stable**.

This document lists the **only** parts of LCMS Core that client plugins may
rely on. Everything not listed here is internal and may change in any release.
Plugins that need internals follow the patch policy in ADR-0004 §2.4.

## How this draft was built

The surface is derived from what the three lcms-engine client apps actually
customized, mapped onto what lcms-core
offers today. Needs that appeared in **all three** clients become extension
points; needs in **two** clients are candidates for core features; single-client
needs stay in plugins, via the API where possible, otherwise as patches.

Each extension point below is marked:

| Mark         | Meaning                                                                        |
|--------------|--------------------------------------------------------------------------------|
| **Exists**   | Implemented in core today; needs docs, RBS and a contract spec to become Stable |
| **Change**   | Partially exists; needs a code change before it can be public                   |
| **New**      | Does not exist; must be built                                                   |

Evidence notation: **C1**, **C2**, **C3** = the three legacy client apps (anonymized).

---

## Summary

| #  | Extension point                         | Mark   | Clients needing it | Priority |
|----|-----------------------------------------|--------|--------------------|----------|
| 1  | Plugin manifest and lifecycle           | New    | all                | P0       |
| 2  | Content tags                            | Change | C1 C2 C3              | P0       |
| 3  | Metadata schema                         | Change | C1 C2 C3              | P0       |
| 4  | Curriculum hierarchy and grades         | Change | C1 C2 C3              | P0       |
| 5  | Content lifecycle events                | Change | C1 C2 C3              | P1       |
| 6  | Output templates (view overrides)       | New    | C1 C2 C3              | P0       |
| 7  | PDF renderers                           | Exists | C1                  | P0       |
| 8  | Output types (exporters, bundles)       | New    | C1 C2 C3              | P1       |
| 9  | Google Doc post-processing              | Change | C1 C2 C3              | P1       |
| 10 | Output styling                          | New    | C1 C2 C3              | P0       |
| 11 | Admin navigation, pages and filters     | Change | C1 C2 C3              | P1       |
| 12 | Plugin data and model extensions        | Change | C1 C2 C3              | P1       |
| 13 | Background jobs                         | Change | C1 C2 C3              | P2       |
| 14 | Public routes and landing page          | Change | C1 C2 C3              | P2       |
| 15 | Settings                                | Exists | all                | P0       |

---

## 1. Plugin manifest and lifecycle — New

Every plugin ships `plugin.yml` at its root, readable without booting Rails
(so client CI can check compatibility before building):

```yaml
# lib/plugins/client_1/plugin.yml
name: client_1
version: 1.3.0
requires_core: "~> 1.4"      # RubyGems requirement syntax
depends_on: [prince_pdf]     # other plugins that must be enabled
```

Lifecycle contract:

- A plugin loads only if listed in `LCMS_PLUGINS` (comma-separated, in load
  order after dependencies are resolved).
- Boot fails if `requires_core` does not match the running core or a
  dependency is missing.
- The entry module `<PluginName>` may define `setup!`. It runs in
  `to_prepare`, so it runs on **every dev reload** and **must be idempotent**
  (register, don't append; no `class_eval` that stacks).
- `setup!` runs after all core registrations, so plugins can override core
  registrations (tags, renderers) deterministically.
- Core exposes `Lcms::VERSION` (semver string).

## 2. Content tags — Change

**Need (C1 C2 C3):** register new tags, override core tags, remove core tags (C2
removes `standard`), add template paths, per-tag config (`stop_tags`,
`priority_descriptions`, per-context and per-locale options).

**Today:** `DocTemplate::Template.register_tag` / `unregister_tag` exist
([template.rb:46](../lib/doc_template/template.rb)); tag config is a
`mattr_accessor` loaded from `config/tags.yml` that plugins can only mutate;
there is no plugin template path.

**Public API:**

```ruby
DocTemplate::Template.register_tag("prompt", Client1::Tags::PromptTag)   # add or override
DocTemplate::Template.unregister_tag("standard")                       # remove
DocTemplate::Tags.configure("callout", stop_tags: %w(SectionTag))      # merge per-tag config
DocTemplate::Tags.prepend_template_path(Client1.root.join("templates"))  # plugin tag templates win
```

**Tag class contract** (`DocTemplate::Tags::BaseTag`) — the public subset:

| Method                                   | Purpose                                         |
|------------------------------------------|-------------------------------------------------|
| `.parse(node, opts)`                     | Entry point used by the template engine         |
| `#parse(node, opts)`                     | Override to transform the tag; returns `self`   |
| `#render`                                | Returns the HTML placeholder content            |
| `#parse_template(context, name)`         | Render an ERB template for the context          |
| `#template_name(opts)`                   | Choose the template (context/locale aware)      |
| `#replace_tag(node)` / `#content_until_break(node)` | Node helpers                         |
| `#gdoc?(opts)`, `#tag_data`, `#materials`| Context helpers                                 |

All other `BaseTag` methods (regexp builders, `splice_tag`, etc.) are internal.
C3 patched `tag_with_html_regexp_array` and the inline markup substitution
(`[b]`, `[i]`) — these stay **outside** the API.

**Changes needed:** `configure` and `prepend_template_path` helpers; move
`config/tags.yml` defaults into `Settings` (ADR-0003 §2.3); locale-aware
template lookup (`name.es.html.erb`) — needed by C2 and C3.

## 3. Metadata schema — Change

**Need (C1 C2 C3):** each client had its own metadata context, service, table
parsers and objects (C1: ~20 table classes, C3: storyline, learning goals, word
wall…).

**Today:** the whole service/context is swappable by class name through the
`doc_template` Setting ([settings.rb:26](../lib/settings.rb)), but inside it
the tables and objects are hard-coded, and `DocTemplate::Objects::Base`
silently drops attributes it doesn't declare
([objects/base.rb:12](../lib/doc_template/objects/base.rb)). Replacing the
whole service means copying core internals.

**Public API:** a registry of metadata tables per content type, instead of
whole-service replacement.

```ruby
Lcms::Metadata.register_table(:lesson, Client1::Metadata::ScopeSequenceTable)
Lcms::Metadata.extend_object(:lesson) do
  attribute :literacy_toolbox, :boolean, default: false
  attribute :segments, array: true
end
Lcms::Metadata.register_validator(:unit, Client1::Metadata::UnitIdValidator)
```

| Contract                    | Shape                                                                                   |
|-----------------------------|-----------------------------------------------------------------------------------------|
| Table class                 | `HEADER_LABEL` (matches the table's header cell), `.parse(fragment) → Hash`, `#errors` |
| Content types               | `:lesson`, `:material`, `:unit`, `:section`, `:activity`                                 |
| `extend_object`             | ActiveModel attribute declarations added to the object for that type                    |
| Validator                   | `#call(metadata, errors)`; appends to `errors`, never raises                             |

Stored metadata stays in the `metadata` JSONB column; extended fields are
queryable with `where_metadata`.

**Changes needed:** table/validator registries inside
`Lt::Lcms::Metadata::Service`; objects accept registered extensions;
retire class-name injection for `metadata.context`/`metadata.service` once
the registry covers the needs (keep for one minor with a deprecation warning).

## 4. Curriculum hierarchy and grades — Change

**Need (C1 C2 C3):** every client decorated `Resource` and `Grades`:
different levels (C1: …/unit/cluster/lesson, C2: …/module/unit/lesson,
C3: …/unit/lesson_set/lesson), different grade lists (C2 adds pk, science,
social studies) and level-specific scopes.

**Today:** `HIERARCHY` and `GRADES` are constants in
[config/initializers/lcms_constants.rb](../config/initializers/lcms_constants.rb).

**Public API:** hierarchy and grades become settings (data, not code):

```ruby
Settings.get(:curriculum, include_defaults: true)
# => { hierarchy: %i(subject grade unit section lesson),
#      grades: [{ key: "grade 1", abbr: "1", label: "Grade 1" }, ...] }
```

Core code reads `Curriculum.hierarchy` / `Curriculum.grades` instead of the
constants. Level-specific predicates and scopes on `Resource`
(`unit?`, `where_level(:cluster)`) are generated from the hierarchy.

**Open:** C1's second, parallel hierarchy for assessments is out of scope for
v1 and stays a C1 patch.

## 5. Content lifecycle events — Change

**Need (C1 C2 C3):** run code after a document/material is built or re-imported
(link resolution, immediate PDF generation, OCX export, thumbnails). C2 and C3
already used `ActiveSupport::Notifications`; C1 used decorators.

**Today:** `document:built`, `material:built`, `unit:built`, `section:built`
are instrumented with `{ id: }` payloads and have no subscribers.

**Public API:** notification events with documented payloads (notify-only,
cannot change results):

| Event                | Payload                                      | Status |
|----------------------|----------------------------------------------|--------|
| `document:built`     | `id`                                         | Exists |
| `material:built`     | `id`                                         | Exists |
| `unit:built`         | `id`                                         | Exists |
| `section:built`      | `id`                                         | Exists |
| `document:reimported`| `id`, `changes` (metadata diff)              | New    |
| `material:reimported`| `id`, `changes`                              | New    |
| `*:generated`        | `id`, `format` (`:pdf`/`:gdoc`), `url`, `renderer` | New |

Subscribers must be registered in `setup!` via `Lcms::Events.subscribe(name)`
(a thin, reload-safe wrapper that avoids duplicate subscriptions on reload).

**Open:** whether we need *filter* hooks that transform values (e.g. C2
filtered presenter parts by bundle type). Proposed: not in v1; add specific
extension points when a concrete need appears.

## 6. Output templates (view overrides) — New

**Need (C1 C2 C3):** all three shipped their own document/material PDF and gdoc
templates (C1 243, C2 120, C3 193 view files), usually by overriding engine views
at the same path.

**Today:** plugin view paths are appended
([config/plugin_paths.rb:32](../config/plugin_paths.rb)), so core views win
and a plugin cannot override them.

**Public API:** plugin view paths are **prepended** for a declared list of
overridable templates. Only these are public; each has documented locals.

| Template                                   | Locals / instance vars                         |
|--------------------------------------------|------------------------------------------------|
| `documents/pdf/_header`, `_content`, `_footer` | `@document` (DocumentPresenter), `@options` |
| `documents/gdoc/_header`, `_content`       | `@document`, `@options`                        |
| `materials/pdf/_header`, `_content`, `_footer` | `@material` (MaterialPresenter), `@options` |
| `materials/gdoc/_header`, `_content`       | `@material`, `@options`                        |
| `documents/_content` (web)                 | `@document`                                    |
| `layouts/pdf`, `layouts/gdoc`              | `yield`, `@options`                            |

The presenter methods usable from these templates are listed in
[§6.1](#61-presenter-surface). Overriding any other view is a patch.

A core check (spec + boot-time warning in development) reports plugin views
that shadow a core view **not** on this list, and plugin overrides of listed
templates whose core counterpart no longer exists — this is how silent
breakage (an override that stops matching) is caught.

**Changes needed:** split the list above into partials where they're not
already (`materials/pdf/_content` and `materials/gdoc/_content` do not exist
today); prepend plugin view
paths; the shadowing check.

### 6.1 Presenter surface

Templates use `DocumentPresenter` / `MaterialPresenter`. The public surface is
a documented method list (title, metadata readers, `render_content`,
`materials`, standards, `pdf_config`…), to be extracted from the current
presenters. C1 and C2 replaced presenters by class name via config; in core that
becomes a registry:

```ruby
Lcms::Presenters.register(:document, Client1::DocumentPresenter) # must subclass DocumentPresenter
```

Subclassing is supported, but only public presenter methods may be overridden.
**Mark: Change** — the method list is the main piece of work here.

## 7. PDF renderers — Exists

Defined by [ADR-0001](adr/0001-pluggable-output-renderers.md):
`Exporters::Pdf::RendererRegistry.register(Klass)`, contract `#call`,
`.identifier`, optional `.capabilities`, `.available?`, `.layout_name`.
Reference plugins: `prince_pdf`, `gdoc_pdf`. Becomes Stable once its RBS and
contract spec are in place.

## 8. Output types (exporters, bundles) — New

**Need (C1 C2 C3):** each client had its own exporters on top of engine base
classes: teacher guides, student bundles, unit readers, zoomed materials, zip
bundles, K5 variants, CSV.

**Today:** exporters and bundle jobs are hard-coded
(`Exporters::Pdf::Base`, `UnitBundlePdfJob`, …).

**Public API:** register named output types built on a public exporter base:

```ruby
Lcms::Outputs.register(:student_book,
  exporter: Client1::Exporters::StudentBook,   # < Exporters::Pdf::Base
  scope: :unit,                               # :document | :material | :unit | :section
  formats: %i(pdf))
```

Registered outputs get generic generation (a core job runs the exporter,
stores the result, fires `*:generated`) and can be listed in admin. The
exporter base exposes a documented subset (`#export`, `#base_path`,
`#template_path`, `#pdf_options`); everything else is internal.

## 9. Google Doc post-processing — Change

**Need (C1 C2 C3):** all three decorated `Google::ScriptService` to choose the
gdoc template per type/orientation and to pass extra parameters, and each
shipped its own Apps Script (`Code.gs`, 200–630 lines).

**Today:** Apps Script ID and templates come from ENV
([script_service.rb:8](../app/services/google/script_service.rb)).

**Public API:**

- Template IDs per orientation and content type in `Settings`
  (not ENV — they're business config).
- `Lcms::Gdoc.register_script_parameters { |record, context| { ... } }` to add
  parameters passed to the script.
- Apps Script source is per client; its function name and parameter contract
  are documented so clients can extend the core script rather than fork it.
- Gdoc publisher registry (ADR-0001 §5.4) — later.

## 10. Output styling — New

**Need (C1 C2 C3):** separate PDF, gdoc and web stylesheets plus fonts
(C1 2.8k, C2 6.2k, C3 4.4k lines of SCSS).

**Today:** `pdf.scss`, `pdf_plain.scss`, `gdoc.scss` import `_tokens.scss`
(all values `!default`), but the sass build is fixed in `package.json` and has
no plugin path.

**Public API:**

- `lib/plugins/<name>/app/assets/stylesheets/_tokens.scss` — if present, it is
  imported **before** core tokens, so plugin values win. The token list is
  public; renaming a token is a breaking change.
- `lib/plugins/<name>/app/assets/stylesheets/{pdf,gdoc}_ext.scss` — appended
  after the core stylesheet for rules tokens can't express.
- Plugin fonts under `app/assets/fonts` are added to the asset path.

**Changes needed:** a build step that composes core + plugin entry points.

## 11. Admin navigation, pages and filters — Change

**Need (C1 C2 C3):** new admin sections (units, bundles, clusters, standards
tools), extra filters on the document/material lists (all three replaced
`QUERY_ATTRS` via `remove_const`), curriculum tree labels (C1, C2).

**Public API:**

- `PluginSystem::MenuRegistry.register` / `.add_to` — **Exists**.
- Admin pages: plugin controllers inherit `Admin::AdminController` (auth,
  layout and flash behavior are the contract); routes in the plugin's
  `config/routes.rb` — **Exists**, needs docs.
- Admin filters — **New**:

  ```ruby
  Lcms::Admin.register_filter(:documents, :module_number,
    label: "Module", type: :select, options: -> { ... },
    scope: ->(relation, value) { relation.where_metadata(:module, value) })
  ```

  Replaces the `doc_template.queries` class-name injection.
- Curriculum tree label: `Lcms::Admin.curriculum_label { |resource| ... }` — **New**.

## 12. Plugin data and model extensions — Change

**Need (C1 C2 C3):** own tables (C1 8, C3 22 migrations), associations from core
models (`Resource has_one :module_bundle`), scopes, audit trails; C2 added
columns to core tables.

**Public API:**

- Plugin migrations and models, table names prefixed `<plugin>_`; excluded
  from core's `db/schema.rb` (ADR-0003 §2.4).
- Model extensions through one declared entry point, applied reload-safely:

  ```ruby
  PluginSystem.extend_model(Resource) do
    has_one :module_bundle, class_name: "Client1::ModuleBundle"
    scope :with_bundles, -> { joins(:module_bundle) }
  end
  ```

  Allowed inside: associations, scopes, `store_accessor` on `metadata`.
  Not allowed (patch): overriding core methods, removing or replacing core
  validations or callbacks.
- **Adding columns to core tables is not supported** — use `metadata` JSONB or
  a plugin table.

## 13. Background jobs — Change

**Need (C1 C2 C3):** many generation/bundle jobs built on engine job concerns
(C1 50, C2 22, C3 41).

**Public API:** plugin jobs inherit `ApplicationJob`; the retry policy and
`JobResult` tracking (`JobTracker`) are the contract. Most client jobs existed
only to generate outputs — [§8](#8-output-types-exporters-bundles) removes the
need for them.

## 14. Public routes and landing page — Change

**Need (C1 C2 C3):** custom public pages (C1 embeddable widgets, C2 SPA + JSON API,
C3 iframe/oEmbed); C1 and C3 redirected the root page.

**Public API:** plugin routes (Exists); `Settings` key for the root page
(redirect target or plugin route) — New. Plugin public controllers inherit
`ApplicationController`.

## 15. Settings — Exists

`Settings.get/set` and the keys in `Settings::DEFAULTS`
([lib/settings.rb](../lib/settings.rb)) are public. Plugins may register their
own settings keys with defaults (`Settings.register_defaults(:client_1, {...})`
— New) so they appear alongside core settings.

---

## Promote to core rather than API

Needed by two or more clients; better as core features (usually behind a
setting) than as per-client plugin code:

| Need                                             | Clients | Notes                                  |
|--------------------------------------------------|---------|----------------------------------------|
| Audit trail (paper_trail) on content models      | C1 C3     | Setting to enable                       |
| Google shared-drive listing                      | C1 C3     | Identical code in both                  |
| S3 upload options (cache-control, local mode)    | C1 C2     |                                         |
| Ghostscript post-processing (CMYK, low-res)      | C1 C2 C3   | PDF post-processor step after renderer  |
| en/es localization of tags and templates         | C2 C3     | See §2 locale-aware templates           |
| Standards scopes and import variants             | C1 C3     |                                         |
| OCX export                                       | C2 C3     | Candidate in-tree plugin                |
| Unit documents (parse `unit` type)               | C1       | Already in core (`UnitBuildService`)    |

## Explicitly outside the API (patch policy applies)

- Inline markup substitution in tags (`[b]`, `[i]`) — C3.
- Removing core model validations — C3 (`Material` identifier).
- Parallel assessment hierarchy — C1.
- User model extensions, registration with access codes, Devise view overrides — C2.
- Any core view not listed in §6.

## Known core issues found while drafting

- `DocumentPart` has `enum :context_type, { default: 0, gdoc: 1 }`
  ([document_part.rb:32](../app/models/document_part.rb)); adding a context via
  the `doc_template.contexts` setting breaks part creation.
- `doc_template.document_contexts` / `material_contexts` are defined but not
  read anywhere.
- `config/plugin_paths.rb` does not add `app/presenters` or `app/forms` of
  plugins to autoload paths.
- Production `Dockerfile` runs `bundle install` before plugin Gemfiles are
  copied (ADR-0003 §1.1).

## Suggested build order

1. **P0 foundation:** manifest + enablement (§1), prepended declared view
   overrides + shadowing check (§6), tokens override (§10), tag helpers (§2),
   hierarchy/grades as settings (§4), metadata registries (§3). Mark renderers
   (§7) and settings (§15) Stable.
2. **P1:** lifecycle events (§5), output types (§8), gdoc post-processing
   (§9), admin filters (§11), `extend_model` (§12).
3. **P2:** jobs (§13), root page (§14), promoted core features.
4. **Validate with the pilot client:** port one client plugin and count the
   patches it still needs; each recurring patch is the next extension point.

## Open questions

- Namespace for new APIs: `Lcms::*` (proposed here) vs extending
  `PluginSystem::*`.
- Filter hooks (value-transforming) in v1 or not (§5).
- Presenter surface: how much of `DocumentPresenter` to make public (§6.1).
- Is `plugin.yml` enough, or should `requires_core` also be checked by a
  RubyGems-style gemspec?
