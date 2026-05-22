# Adding a PDF Renderer Plugin

This is a hands-on tutorial. By the end you'll have a working renderer plugin loaded at boot, selectable from the admin Settings UI, with conformance tests in place.

For the *why* behind the design (decoupling, capabilities, two-tier model, etc.) see [ADR-0001](adr/0001-pluggable-output-renderers.md). For an overview of selection precedence and runtime behavior see [pdf-generation.md](pdf-generation.md). This document is the *how*.

Reference implementation: [`lib/plugins/prince_pdf/`](../lib/plugins/prince_pdf/). When in doubt, crib from it.

---

## Step 1 — Scaffold the plugin folder

Pick a short, lowercase, underscored name for your plugin. We'll use `my_pdf` throughout.

```bash
mkdir -p lib/plugins/my_pdf/{lib/my_pdf,spec/my_pdf,sig/my_pdf}
touch lib/plugins/my_pdf/{Gemfile,README.md}
touch lib/plugins/my_pdf/lib/my_pdf.rb
touch lib/plugins/my_pdf/lib/my_pdf/renderer.rb
touch lib/plugins/my_pdf/spec/my_pdf/renderer_spec.rb
```

Minimal layout:

```
lib/plugins/my_pdf/
  Gemfile                       # plugin-specific gems (often empty for renderers)
  README.md                     # what the plugin does, license, install reqs
  lib/
    my_pdf.rb                   # entry point: setup! hook
    my_pdf/
      renderer.rb               # the PDF renderer
  spec/
    my_pdf/
      renderer_spec.rb
```

For richer plugins (custom layout, options translator, executable wrapper, accessibility CSS), use [`lib/plugins/prince_pdf/`](../lib/plugins/prince_pdf/) as the template. None of those are required by the protocol.

### Gem dependencies

The host [`Gemfile`](../Gemfile) auto-loads every plugin Gemfile via:

```ruby
Dir[File.join("lib/plugins/*/Gemfile")].each { |f| eval_gemfile(f) }
```

So **gems your renderer needs go in `lib/plugins/my_pdf/Gemfile`, not the host Gemfile.** This keeps the plugin self-contained — a fork that doesn't enable your renderer doesn't carry the gem dependency.

```ruby
# lib/plugins/my_pdf/Gemfile
# frozen_string_literal: true

gem "my_backend", "~> 1.2"
```

After editing, run `bundle install` to lock the new dependency. The plugin Gemfile may be empty — Prince's plugin has no Ruby deps because the backend is a system binary invoked via `Open3`.

## Step 2 — Write the entry-point module

`lib/plugins/my_pdf/lib/my_pdf.rb`:

```ruby
# frozen_string_literal: true

module MyPdf
  class << self
    def setup!
      ::Exporters::Pdf::RendererRegistry.register(Renderer)
      PluginSystem.logger.info \
        "[MyPdf] :my_pdf renderer registered (available=#{Renderer.available?})"
    end
  end
end
```

`PluginSystem.load_all` (invoked from [config/initializers/plugins.rb](../config/initializers/plugins.rb) in a `to_prepare` hook) calls `setup!` on every module under `lib/plugins/`. You don't need to register your plugin anywhere — dropping the folder in is sufficient.

### Boot-time configuration belongs in `setup!`

If your backend has a global `.configure` block (Grover, WickedPdf, etc.), put it **inside `setup!`** before the `register` call. **Plugins do not ship `config/initializers/*.rb` files** — the auto-discovery iterates only over plugin Ruby modules, not Rails initializer paths. The `setup!` hook IS the plugin's boot-time initialization point.

```ruby
module GroverPdf
  class << self
    def setup!
      ::Grover.configure do |config|
        config.options = {
          executable_path: ENV.fetch("GROVER_EXECUTABLE_PATH", nil),
          wait_until: "networkidle0",
          timeout: ENV.fetch("PUPPETEER_TIMEOUT", 0).to_i
        }
      end
      ::Exporters::Pdf::RendererRegistry.register(Renderer)
    end
  end
end
```

Because `setup!` runs inside Rails' `to_prepare` hook, it re-runs on every dev-mode code reload — safe for idempotent operations (registration overwrites by identifier; `.configure` overwrites a global). Don't put one-shot side effects (DB writes, network calls, file creation) here.

## Step 3 — Implement the renderer

`lib/plugins/my_pdf/lib/my_pdf/renderer.rb`:

```ruby
# frozen_string_literal: true

module MyPdf
  class Renderer < ::Exporters::Pdf::Renderers::Base
    CAPABILITIES = Set[
      # Declare what this backend supports. See "Capability vocabulary" below.
    ].freeze

    def self.identifier   = :my_pdf
    def self.capabilities = CAPABILITIES
    def self.layout_name  = "pdf"          # ERB layout to render the body in
    def self.available?   = true           # set to false when runtime deps are missing

    def call(html, options:)
      # Translate `options` (an Exporters::Pdf::RenderOptions) into your backend's
      # native option format, then render `html` to PDF bytes and return them.
      raise NotImplementedError
    end
  end
end
```

The protocol the registry enforces:

| Method | Required? | Type | Default (from `Base`) |
|---|---|---|---|
| `.identifier` | yes | `Symbol` | — |
| `#call(html, options:)` | yes | `String` (PDF bytes) | — |
| `.capabilities` | no | `Set[Symbol]` | empty set |
| `.available?` | no | `Boolean` | `true` |
| `.layout_name` | no | `String` | `"pdf"` |

Inheriting `Base` is not required — duck-typed implementations satisfy the registry equally — but it gives you the optional-method defaults for free.

## Step 4 — Declare capabilities

`.capabilities` returns a `Set` of symbols describing what the backend can do. The registry's accessibility gate uses these to reject mismatched (renderer, accessibility) combos at lookup time, before any HTML is rendered.

### Capabilities that gate accessibility

These are checked by `RendererRegistry.fetch_for(identifier:, accessibility:)`:

| Capability | Required for `accessibility:` |
|---|---|
| `:tagged_pdf` | `:tagged` |
| `:pdf_ua` | `:pdf_ua` |

If you support either tier of accessibility output, declare the corresponding capability. Otherwise leave them out — Grover, for example, declares neither.

### Informational capabilities

Not enforced, but useful for documentation and future feature flags. Common ones used by existing renderers:

- `:landscape` — supports landscape orientation
- `:web_fonts` — embeds web fonts
- `:js_execution` — runs JavaScript in the rendered page
- `:running_headers` — supports CSS `position: running()` for paged headers/footers
- `:background_print` — honors `print-color-adjust: exact`
- `:custom_script_hook` — supports a renderer-side script injection point

When in doubt, look at [`PrincePdf::Renderer::CAPABILITIES`](../lib/plugins/prince_pdf/lib/prince_pdf/renderer.rb) for a maximalist example.

## Step 5 — Translate `RenderOptions` to your backend's options

`options` arrives as an [`Exporters::Pdf::RenderOptions`](../lib/exporters/pdf/render_options.rb) — a `Data` object with these fields:

| Field | Type | Notes |
|---|---|---|
| `format` | String | e.g. `"Letter"`, `"A4"` |
| `orientation` | String | `"portrait"` \| `"landscape"` |
| `margin` | Hash\|nil | `{ top:, right:, bottom:, left: }` — CSS length strings |
| `dpi`, `image_dpi` | Integer\|nil | |
| `print_background` | Boolean | |
| `header_html`, `footer_html` | String\|nil | already-rendered HTML fragments |
| `metadata` | Hash | `{ title:, lang: }` — author/title/lang hints |
| `accessibility` | Symbol | `:none` \| `:tagged` \| `:pdf_ua` |
| `extra` | Hash | escape hatch for renderer-specific options |

Helper methods: `landscape?`, `portrait?`, `accessible?`.

Renderers extract the subset they care about. Two common patterns:

### Pattern A — direct extraction inside `#call` (smaller renderers)

```ruby
def call(html, options:)
  MyBackend.render(html,
    format: options.format,
    landscape: options.landscape?,
    margins: options.margin,
    pdf_ua: options.accessibility == :pdf_ua
  )
end
```

### Pattern B — `OptionsTranslator` class (larger renderers)

Used by `PrincePdf` — see [`options_translator.rb`](../lib/plugins/prince_pdf/lib/prince_pdf/options_translator.rb). The renderer's `#call` becomes:

```ruby
def call(html, options:)
  args = OptionsTranslator.new(options).to_args
  Backend.run(args, stdin: html)
end
```

Pattern B is worth the indirection when the translation is non-trivial (multi-step, conditional flags, asset paths) or when you want to test option mapping in isolation.

## Step 6 — Add a layout (only if your renderer needs custom HTML)

By default, renderers use the shared [`app/views/layouts/pdf.html.erb`](../app/views/layouts/pdf.html.erb) — the body content is wrapped in the standard PDF layout.

If your backend needs a different `<head>` (e.g. embedded metadata for PDF/UA, a different stylesheet link, a custom `<html lang>`), ship your own layout at `lib/plugins/my_pdf/app/views/layouts/pdf_my_pdf.html.erb` and point `.layout_name` at it:

```ruby
def self.layout_name = "pdf_my_pdf"
```

Plugin views are auto-discovered via `lib/plugins/*/app/views/` (Rails view path). Reference: [`lib/plugins/prince_pdf/app/views/layouts/pdf_prince.html.erb`](../lib/plugins/prince_pdf/app/views/layouts/pdf_prince.html.erb).

## Step 7 — Write specs

`lib/plugins/my_pdf/spec/my_pdf/renderer_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

describe MyPdf::Renderer do
  it_behaves_like "a PDF renderer"

  # Add backend-specific examples here:
  #   - input/output transformations
  #   - error handling when the backend fails
  #   - capability assertions specific to your renderer
end
```

`it_behaves_like "a PDF renderer"` is the shared conformance suite ([`spec/support/shared_examples/pdf_renderer.rb`](../spec/support/shared_examples/pdf_renderer.rb)). It checks:

- Protocol surface (identifier, call, capabilities, available?, layout_name) returns the right types
- The renderer round-trips through `RendererRegistry.register` without raising `ContractViolation`
- It's fetchable by its identifier when `available?`

It does **not** verify your renderer actually produces a valid PDF — that requires runtime deps and belongs in your plugin's integration tests (typically gated on whether the backend's binary is installed).

Run just your plugin's specs:

```bash
docker compose run --rm test bundle exec rspec lib/plugins/my_pdf/spec
```

The `.rspec` `--pattern` already includes `lib/plugins/**/spec/**/*_spec.rb`, so plugin specs run as part of the main suite by default.

## Step 8 — Verify registration at boot

```bash
docker compose run --rm rails rails runner '
  reg = Exporters::Pdf::RendererRegistry
  puts "registered: #{reg.all.inspect}"
  puts "available:  #{reg.available.inspect}"
'
```

Expected output includes `:my_pdf` in both lists. If it's in `registered` but not `available`, your `available?` is returning `false` — usually because a runtime dependency isn't installed (Step 10).

If it doesn't appear at all, check the Rails logs at boot for a `[PluginSystem]` line: each plugin's `setup!` is called once per dev-mode `to_prepare` cycle, with the failure message captured at the `PluginSystem.logger.error` level.

## Step 9 — Test end-to-end

Set your renderer as the default via the admin Settings UI at `/admin/settings` — it should appear in the "Default PDF renderer" dropdown (the dropdown's options come from `RendererRegistry.available`).

Then hit a preview URL with `FORCE_PREVIEW_GENERATION=true` (or clear `preview_links` first):

```
http://localhost:3000/documents/<id>/preview/pdf?type=<content_type>
http://localhost:3000/materials/<id>/preview/pdf
```

Inspect the generated PDF's metadata to confirm your renderer ran:

```bash
docker compose run --rm rails bash -c '
  curl -s "<the s3 url>" | strings | grep -E "Producer|Creator" | head -3
'
```

You should see your backend's signature (e.g., `Producer: WeasyPrint`, `Producer: wkhtmltopdf`). Compare to Grover's `Producer: Skia/PDF`.

## Step 10 — Install runtime dependencies

Most renderers wrap an external binary or service. You have three places to ensure it's available:

### Local development — Dockerfile.dev

Add an apt/gem/binary install step to [`Dockerfile.dev`](../Dockerfile.dev). Pin versions; document the rationale in a comment. Example pattern from the Prince install:

```dockerfile
RUN set -e; \
    ARCH=$(dpkg --print-architecture); \
    apt-get update -qq; \
    wget -q "https://example.com/my-backend-${ARCH}.deb" -O "/tmp/my-backend.deb"; \
    gdebi --non-interactive "/tmp/my-backend.deb"; \
    rm "/tmp/my-backend.deb"; \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
```

### Production — Cloud66

Ship an idempotent install script under [`.cloud66/scripts/install-my-backend.sh`](../.cloud66/scripts/) and wire it into [`.cloud66/deploy_hooks.yml`](../.cloud66/deploy_hooks.yml) as a `first_thing` hook. Pattern: [`.cloud66/scripts/install-prince-xml.sh`](../.cloud66/scripts/install-prince-xml.sh).

### Documentation — your plugin's README

`lib/plugins/my_pdf/README.md` should list:

- What runtime binary/service is required
- License terms if commercial (Prince's "non-commercial watermark" trap is a good template)
- Environment variables your renderer reads (e.g., binary path, license file path)
- Links to upstream installation docs

**Why install scripts live in the main repo, not the plugin folder:** convention-based plugin self-provisioning was considered and rejected for v1 — see [ADR-0001 §4.4](adr/0001-pluggable-output-renderers.md#44-docker-and-cloud66-integration). The expectation is to revisit once 3+ plugins ship their own provisioning.

## What you don't need to do

- **No route changes** — the renderer is invoked through `Exporters::Pdf::Document#export` and its kin; selection happens via the registry, not via per-renderer URLs.
- **No controller changes** — `DocumentsController#preview_pdf`, `MaterialsController#preview_pdf`, and the PDF jobs all go through the same registry call.
- **No view-template changes (usually)** — the existing partials under `app/views/{documents,materials}/pdf/` are renderer-agnostic. Only swap the `.layout_name` if you need a different `<head>`.
- **No background-job changes** — `DocumentPdfJob` and `MaterialPdfJob` already work for any registered renderer.

## Common pitfalls

1. **Forgot to call `setup!`** — Plugin Ruby code loaded but renderer never registered. Cause: you defined the module but didn't add the `def setup!` method. The system calls `MyPdf.setup!` if it exists; without it, nothing happens. Check the boot logs for `[PluginSystem] Loaded: my_pdf` — if you see only that and not your registration log line, `setup!` is missing.

2. **`available?` returns `false`** — Registered but filtered out. Usually a path or binary check failing inside `available?`. Test from the console: `MyPdf::Renderer.available?` — debug from there.

3. **Capability mismatch raised as `UnsupportedCapability`** — The registry rejects (your renderer, `:pdf_ua`) because you didn't declare `:pdf_ua` in `CAPABILITIES`. Either declare it (and actually support it!) or accept that your renderer is only usable for non-accessible PDFs.

4. **Dev-mode reload wipes the registry** — If you edit `lib/exporters/pdf/renderer_registry.rb` and the dropdown goes empty, that's a `to_prepare` vs `after_initialize` issue. The plugin initializer uses `to_prepare` precisely to survive Zeitwerk reloads; if your registration drops the table, check that you're using `to_prepare`.

## When you ship

- Update [docs/pdf-generation.md](pdf-generation.md) "Available renderers" table with your row
- Add an integration test that actually invokes your binary (gated on the binary being installed) so CI catches breakage
- Open a PR — the protocol-conformance suite from `it_behaves_like "a PDF renderer"` already ran in the spec suite, so reviewers can focus on backend-specific behavior

---

## Migrating an existing renderer into a plugin

This guide is structured for greenfield plugins. If you're **extracting** an existing renderer from the host app into a plugin (e.g., turning the in-tree `Exporters::Pdf::Renderers::Grover` into a `lib/plugins/grover_pdf/`), follow Steps 1–9 above, then do this cleanup checklist:

### Files to move

| From (host app) | To (plugin) |
|---|---|
| `lib/exporters/pdf/renderers/<name>.rb` | `lib/plugins/<name>_pdf/lib/<name>_pdf/renderer.rb` |
| `config/initializers/<name>.rb` content | inlined into `<NamePdf>.setup!` (delete the file) |
| `spec/lib/exporters/pdf/renderers/<name>_spec.rb` | `lib/plugins/<name>_pdf/spec/<name>_pdf/renderer_spec.rb` |
| `sig/lib/exporters/pdf/renderers/<name>.rbs` | `lib/plugins/<name>_pdf/sig/<name>_pdf/renderer.rbs` |
| `gem "<backend>"` line from host `Gemfile` | plugin `Gemfile` |

### Lines to remove from the host app

- The `Exporters::Pdf::RendererRegistry.register(...)` call in [`config/initializers/pdf_renderers.rb`](../config/initializers/pdf_renderers.rb) — registration now happens in the plugin's `setup!`
- Any host-app references to the renderer class constant (`Exporters::Pdf::Renderers::Grover`) — they should be referenced through the registry (`RendererRegistry.fetch(:grover)`) instead
- The renderer's row from [`Steepfile`](../Steepfile) if its sig was listed individually — plugin sigs are picked up automatically via `lib/plugins/*/sig`

### Docs to update

- [`docs/pdf-generation.md`](pdf-generation.md) — move the renderer's "(default renderer)"-style section out of the host docs (or update it to reflect plugin location)
- [`docs/adr/0001-pluggable-output-renderers.md`](adr/0001-pluggable-output-renderers.md) — if the ADR cited the renderer as in-tree, update §4 or note in §5 "What changed"

### Validation

After extraction, the following should still pass without any code changes outside the plugin:

```bash
docker compose run --rm test bundle exec rspec
docker compose run --rm rails bundle exec steep check
docker compose run --rm rails rails runner '
  puts Exporters::Pdf::RendererRegistry.available.inspect
  puts Exporters::Pdf::RendererRegistry.default.inspect
'
```

If `available` is missing your identifier, the plugin's `setup!` isn't being called — check for a `[PluginSystem] Loaded: <name>` line at boot, and that the module name in `lib/plugins/<name>_pdf/lib/<name>_pdf.rb` matches the folder name (camelized).

### Why extract?

- **Optional dependency.** Forks that don't need your renderer don't pay for the gem/runtime install.
- **Cleaner ownership.** Renderer-specific code lives next to the registration that activates it; no scattering across `lib/exporters/`, `config/initializers/`, and the host Gemfile.
- **Parity with future renderers.** Treating every renderer (even the default) as a plugin removes the special case in the architecture.

The trade-off: the "default renderer" loses some discoverability — a new reader of the host app sees zero renderers and has to know to look in `lib/plugins/`. The [pdf-generation.md](pdf-generation.md) "Available renderers" table covers this.

---

## Related docs

- [pdf-generation.md](pdf-generation.md) — renderer selection, options chain, runtime behavior
- [plugin-system.md](plugin-system.md) — generic plugin authoring (not PDF-specific)
- [ADR-0001](adr/0001-pluggable-output-renderers.md) — design rationale, protocol spec
