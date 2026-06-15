# PDF Generation

PDF rendering goes through a pluggable renderer abstraction. The default renderer is **Grover** (headless Chromium via Puppeteer); additional renderers can be registered via plugins. Architecture rationale: [ADR-0001](adr/0001-pluggable-output-renderers.md).

## How it works

Every PDF job ([`DocumentPdfJob`](../app/jobs/document_pdf_job.rb), [`MaterialPdfJob`](../app/jobs/material_pdf_job.rb), [`UnitBundlePdfJob`](../app/jobs/unit_bundle_pdf_job.rb)) constructs an `Exporters::Pdf::Document`/`Pdf::Material` exporter, which:

1. Resolves which renderer to use (chain: per-call option → per-record metadata → registry default)
2. Resolves accessibility level (chain: per-call option → per-record metadata → `:none`)
3. Asks `Exporters::Pdf::RendererRegistry` for the renderer matching that combination — fails fast if the renderer can't satisfy the requested accessibility level
4. Renders the HTML through the renderer's preferred layout
5. Calls the renderer with renderer-neutral [`RenderOptions`](../lib/exporters/pdf/render_options.rb)
6. Returns PDF bytes for upload

No job code changes when a new renderer plugin is added — the seam is inside the exporter.

## Available renderers

| Identifier | Source                                                  | Strengths                                             | Limits                                                                 |
|------------|---------------------------------------------------------|-------------------------------------------------------|------------------------------------------------------------------------|
| `:grover`   | core, default                                           | Modern CSS, JS execution, web fonts, fast             | Cannot produce PDF/UA-1 (tagged accessible PDFs)                       |
| `:prince`   | [`lib/plugins/prince_pdf/`](../lib/plugins/prince_pdf/) | PDF/UA-1, true paged-media typography, embedded fonts | Commercial license, controlled JS environment, separate binary install |
| `:gdoc_pdf` | [`lib/plugins/gdoc_pdf/`](../lib/plugins/gdoc_pdf/)     | Exact parity with the published Google Doc (Apps-Script headers/footers, Docs layout) | Requires Drive credentials, not accessible, 10 MB export ceiling, slower |

Run `Exporters::Pdf::RendererRegistry.available` from the console to see what's currently usable on the host.

## Selecting a renderer

| Form                        | Example                                                                              | Resolution priority              |
|-----------------------------|--------------------------------------------------------------------------------------|----------------------------------|
| Per-call option             | `DocumentPdfJob.perform_later(id, renderer: :prince)`                                | highest                          |
| Shorthand for accessibility | `DocumentPdfJob.perform_later(id, accessible_pdf: true)`                             | maps to `accessibility: :pdf_ua` |
| Per-record metadata         | `doc.update!(metadata: { "pdf_renderer" => "prince", "accessibility" => "pdf_ua" })` | middle                           |
| Global default              | `DEFAULT_PDF_RENDERER=prince` env var                                                | lowest                           |

`Document#pdf_renderer` and `Document#accessibility` accessors are provided by the [`PdfRenderable`](../app/models/concerns/pdf_renderable.rb) concern (included in both Document and Material). `accessibility=` validates against `[none, tagged, pdf_ua]`.

## Adding a new renderer

**See the step-by-step tutorial: [adding-a-pdf-renderer.md](adding-a-pdf-renderer.md).** It walks through scaffolding the plugin folder, satisfying the protocol, declaring capabilities, translating options, writing conformance tests, and installing runtime deps.

In short: a plugin under `lib/plugins/<name>/` registers a renderer in its `setup!`:

```ruby
module MyPdf
  def self.setup!
    Exporters::Pdf::RendererRegistry.register(MyPdf::Renderer)
  end
end
```

The renderer satisfies a small protocol (2 required methods, 3 optional). Inheriting `Exporters::Pdf::Renderers::Base` is the easy path; duck-typed implementations work too. The registry validates the protocol at registration time. Protocol-level conformance is covered by `it_behaves_like "a PDF renderer"` (in [spec/support/shared_examples/pdf_renderer.rb](../spec/support/shared_examples/pdf_renderer.rb)).

## Grover (default renderer)

Backed by [`Grover`](https://github.com/Studiosity/grover) — Ruby gem driving headless Chromium via Puppeteer. Configuration in [`config/initializers/grover.rb`](../config/initializers/grover.rb).

### Local development
1. Install Puppeteer (and any missing Chrome libraries — see [troubleshooting](https://pptr.dev/troubleshooting)): `nvm use && yarn install`
2. Set `ENABLE_BASE64_CACHING=false` (or remember to clear cache when PDF-related CSS/images change)
3. Use your own S3 bucket to avoid overwrite conflicts (`AWS_S3_BUCKET_NAME`)

### Cloud66 deployment
Puppeteer downloads browsers into `~/.cache/puppeteer`. Cloud66 deploys as a different user, so set the cache location via `.puppeteerrc.cjs`:

```js
const { join } = require("path");

module.exports = {
  cacheDirectory: process.env["STACK_BASE"] ? join(__dirname, ".cache", "puppeteer") : null,
};
```

### PDF security policy
After fresh server installation, ImageMagick's policy may block PDF coder. Edit `/etc/ImageMagick-6/policy.xml`:

```xml
<!-- before -->
<policy domain="coder" rights="none" pattern="PDF" />
<!-- after -->
<policy domain="coder" rights="read|write" pattern="PDF" />
```

## PrinceXML (accessible PDFs, optional plugin)

Ships in-tree at `lib/plugins/prince_pdf/`. Used when an accessible PDF (PDF/UA-1) is required — Grover cannot produce tagged PDFs.

PrinceXML is a separate commercial binary. Without a license, output is watermarked. Installation, license setup, Docker integration, env vars, and operator notes live in the plugin's own [`README.md`](../lib/plugins/prince_pdf/README.md).

When the binary isn't installed on a host, `:prince` is registered but filtered out of `RendererRegistry.available` — explicit fetches raise `RendererUnavailable` rather than silently falling back to Grover (preserves the accessibility contract).

## Related docs
- [ADR-0001: Pluggable Output Renderers](adr/0001-pluggable-output-renderers.md) — full architecture context, future-format extensibility
- [PrincePdf plugin README](../lib/plugins/prince_pdf/README.md) — PrinceXML install, license, operator concerns
- [Plugin system](plugin-system.md) — how plugins are discovered and loaded
