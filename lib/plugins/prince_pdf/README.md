# PrincePdf

Accessible PDF rendering for LCMS Core via [PrinceXML](https://www.princexml.com/). Plugs into `Exporters::Pdf::RendererRegistry` as `:prince`. Activated when a job or document opts into accessibility output (PDF/UA-1), which the default Grover/Chromium renderer cannot produce.

This plugin ships in-tree under `lib/plugins/prince_pdf/`. PrinceXML itself is a separate system binary, not a Ruby gem — see installation below.

## When to use it

Use the `:prince` renderer when:

- **PDF/UA-1 compliance** is required (tagged PDFs validating against pac3 / veraPDF for assistive technology)
- **High-fidelity print typography** is needed (running headers/footers, complex page boxes, hyphenation, font embedding)
- **PDF metadata** (title, lang, author) needs to land in the output PDF

Stick with the default `:grover` renderer when:

- Output goes to screen viewing only (no accessibility requirement)
- Templates rely on JavaScript rendered DOM that Prince's controlled JS environment doesn't support

## Installation

PrinceXML is a commercial product. Free non-commercial / evaluation use produces watermarked output; production use requires a license.

### Docker (recommended)

PrinceXML is installed by the main [`Dockerfile.dev`](../../../Dockerfile.dev) — multi-arch (amd64 + arm64), pinned to Prince 16.1 / Debian 12. Rebuilding the dev image is enough; no extra steps are required.

Forks that don't need accessible PDF output can drop the `wget`/`gdebi` packages and the `RUN` block that installs Prince from `Dockerfile.dev`.

### Cloud66

Cloud66 deploys run [`.cloud66/scripts/install-prince-xml.sh`](../../../.cloud66/scripts/install-prince-xml.sh) automatically via the `first_thing` deploy hook (see [`.cloud66/deploy_hooks.yml`](../../../.cloud66/deploy_hooks.yml)). The script is idempotent — it skips if `prince` is already on PATH, otherwise installs `wget`/`gdebi` if missing, downloads the official Ubuntu 22.04 amd64 .deb, and verifies post-install.

For other bare-metal hosts, run the same script manually with `sudo`.

### Verifying

```bash
prince --version
# Prince 16.1
```

## License

PrinceXML is commercial software by YesLogic. Without a license file, output PDFs include a watermark — usable for development, not for production.

To install a license on a Cloud66 server:

```bash
sudo -i -u cloud66-user
mkdir -p "$STACK_BASE/shared/princexml"
cp license.dat "$STACK_BASE/shared/princexml/"
chown -R cloud66-user:cloud66-user "$STACK_BASE/shared/princexml/"
```

Then set `PRINCE_LICENSE_PATH` in the deployment environment:

```bash
PRINCE_LICENSE_PATH="$STACK_BASE/shared/princexml/license.dat"
```

If `PRINCE_LICENSE_PATH` is unset, Prince looks in its default install directory.

Verify license is picked up:

```bash
prince --version --license-file=$PRINCE_LICENSE_PATH
# Prince 16.1
# Server License (Academic)
```

## Environment variables

| Variable                  | Purpose                                                                  |
|---------------------------|--------------------------------------------------------------------------|
| `PRINCE_EXECUTABLE_PATH`  | Path to `prince` binary. Defaults to whatever's on `$PATH`.              |
| `PRINCE_LICENSE_PATH`     | Absolute path to `license.dat`. Unset = default install dir = watermarked. |
| `DEFAULT_PDF_RENDERER`    | Set to `prince` to make accessible the global default for all PDFs.       |

## How selection works

Once installed and registered, the renderer is selected by:

1. **Per-call option** — `DocumentPdfJob.perform_later(doc_id, renderer: :prince)` or `accessible_pdf: true` (shorthand)
2. **Per-record metadata** — `document.metadata['pdf_renderer'] = "prince"` or `metadata['accessibility'] = "pdf_ua"`
3. **Global default** — `DEFAULT_PDF_RENDERER=prince`

Resolution order: per-call → per-record → global default.

If the renderer is registered but the binary isn't on the host (e.g. a fork that stripped the Prince install from `Dockerfile.dev`, or a bare-metal host where the install script wasn't run), `Renderer.available?` returns `false` and the registry filters `:prince` out. Any record asking for `:prince` then fails fast with `RendererUnavailable` — never silently downgraded to Grover, since the accessibility contract would be lost.

## Templates and accessibility

PDF/UA-1 compliance requires both Prince *and* tagged HTML. The plugin ships a tagging stylesheet (`prince_xml.css`, added in a later commit) that maps standard HTML elements to PDF semantic tags via `prince-pdf-tag-type:` rules. Most lessons render acceptably tagged out of the box.

For strict pac3 / veraPDF certification, operators should also author accessibility-grade template variants per PDF component (semantic markup, ARIA where applicable, decorative-image artifact marking via the `icon-as-artifact` helper). See ADR-0001 §4.5 for the full pattern.

## See also

- [ADR-0001: Pluggable Output Renderers](../../docs/adr/0001-pluggable-output-renderers.md) — architecture context
- [PrinceXML documentation](https://www.princexml.com/doc/) — full CLI reference
- [Prince tagged-PDF guide](https://www.princexml.com/doc/tagged-pdf/) — PDF/UA semantics
