# GdocPdf

PDF rendering via Google Doc export for LCMS Core. Plugs into
`Exporters::Pdf::RendererRegistry` as `:gdoc_pdf`.

Instead of rendering HTML through a print engine (like the default `:grover`
or the accessible `:prince` renderer), this renderer exports the record's
**actual generated Google Doc** to PDF via the Drive `files.export` endpoint.
The output is identical in styling to the published Google Doc — the same
Apps-Script-applied headers/footers and the same Docs layout engine — which
HTML-based renderers cannot reproduce exactly.

This plugin ships in-tree under `lib/plugins/gdoc_pdf/`.

## When to use it

Use the `:gdoc_pdf` renderer when the PDF **must match the Google Doc
exactly** — i.e. the Google Doc is the canonical deliverable and the PDF is
just a download of it.

Stick with `:grover` (default) or `:prince` when:

- You need **PDF/UA-1 accessibility** — Google Docs export is not certifiable
  (`:gdoc_pdf` advertises no accessibility capability, so the registry
  refuses `:gdoc_pdf` + `:tagged` / `:pdf_ua` requests).
- You need **print-engine fidelity** to the web/HTML rendering rather than to
  the Google Doc.
- The document has **no Google Doc** and you don't want the render to create
  one (this renderer will generate one on demand — see below).

## How it works

1. **Reuse** — if the record already has a Google Doc link in
   `links[content_type]["gdoc"]`, that doc is exported as-is. There is **no
   staleness check**: the PDF faithfully mirrors the published Google Doc,
   even if the doc predates the latest content edits.
2. **Generate (ephemeral)** — if no Google Doc link exists, the full Gdoc
   pipeline runs (`Exporters::Gdoc::Document` / `Material`, including the
   `Google::ScriptService` Apps Script post-processing), then the resulting
   doc is exported. The generated doc is **not** written back into the
   record's `links` — generation is a side effect of the render, not a change
   to the Google Doc lifecycle. The pipeline updates an existing same-named
   doc in place rather than creating duplicates, so repeated renders are
   idempotent.

The record reaches the renderer through `RenderOptions#source`, which
`Exporters::Pdf::Base` threads in. (HTML-based renderers ignore it.)

## Selecting the renderer

Selection uses the standard chain (per-call option → per-record metadata →
project default):

```ruby
# Per call
DocumentPdfJob.perform_later(doc.id, content_type: :unit_bundle, renderer: :gdoc_pdf)

# Per record (requires a plugin that exposes #pdf_renderer from metadata)
doc.update!(metadata: doc.metadata.merge("pdf_renderer" => "gdoc_pdf"))

# Project default
# DEFAULT_PDF_RENDERER=gdoc_pdf  (env), or the pdf.default_renderer admin Setting
```

## Runtime requirements

- **Google Drive credentials** — the same file-based service-account
  credentials used by the Gdoc pipeline, resolved via
  `Lt::Google::Api::Auth::Cli`. When credentials cannot be resolved,
  `Renderer.available?` returns `false` and the registry filters `:gdoc_pdf`
  out of `.available`; records requesting it then fail fast.
- The same `GOOGLE_APPLICATION_*` environment variables the Gdoc pipeline
  relies on (folder ID, Apps Script ID/function, portrait/landscape template
  IDs) — only needed for the *generate* path.

## Limitations & risks

- **10 MB export ceiling** — Drive's `files.export` rejects results larger
  than 10 MB. Large unit bundles may exceed it and raise `ExportError`.
- **Not accessible** — output is not PDF/UA-1.
- **Latency** — the reuse path is a single Drive export call (fast); the
  generate path performs an HTML→Docs upload, an Apps Script round-trip, and
  the export, so it is markedly slower and subject to Drive rate limits
  (retried with backoff via `retriable`).
- **Wasted HTML render** — `Exporters::Pdf::Base` always renders the PDF
  template HTML before invoking the renderer; `:gdoc_pdf` discards it. This is
  an accepted cost of fitting a Google-Doc-export operation into the
  HTML-in / bytes-out renderer contract.

## Tuning (environment variables)

| Variable | Default | Purpose |
|---|---|---|
| `GDOC_PDF_EXPORT_TRIES` | `5` | Retries for rate-limited / transient Drive errors during export |
| `GDOC_PDF_EXPORT_BASE_INTERVAL` | `5` | Base backoff interval (seconds) between export retries |
