# LCMS Core Styling Defaults — Needs Clarification

Working notes for the "LCMS Core Styling Defaults" initiative. The source spec
("LCMS Core Styling Defaults" — Google Doc) is mostly clear at the typography
and page-layout level. This file tracks open questions, decisions already made,
and items that must be answered before the corresponding implementation phase
can start.

## Scope (working assumption)

This initiative covers the **default Grover/Chromium-rendered** Lesson, Material,
and Bundle exports (PDF + Google Doc). PrinceXML is **out of scope** here and
will be delivered as a separate plugin in its own PR/branch.

---

## Resolved decisions

### R1. PrinceXML — out of scope
PrinceXML support will be implemented in a separate PR and branch. The defaults
shipped by this initiative target the existing Grover/Chromium pipeline only.

### R2. Lesson document footer — confirmed design
Footer placement: bottom of page, separated from page content by a horizontal
rule above the footer block.

Footer contents (two rows under the divider line, left-aligned with page number
right-aligned on the second row):

- Row 1: `© <Company Name>, <Season Year>` — regular weight, small (~9–10 pt).
  - Example: `© Company Name, Spring 2026`.
- Row 2 (bold):
  - Left: `<Grade>/Course • <Title of Unit> • Lesson <N>`
  - Right: `<page number>`

Open follow-ups for the footer (deferred to Q-related items below):
- Source of `Company Name` and `Season Year` — config? unit/lesson metadata?
- Whether the same footer pattern applies to **Materials** and **Bundles**, or
  if those get their own designs (see Q2 below).

### R3. Phase-1 SCSS uses `!important` as a temporary hammer
The first SCSS pass in `app/assets/stylesheets/pdf.scss` uses `!important` on
font-family, font-size, color, and line-height for body/paragraph/span/li/td/th
and on heading rules. Reason: imported Google-Doc HTML carries inline
`style="font-family: ...; font-size: ...; color: ..."` on every element, and
inline styles beat any class selector. Without `!important`, our defaults have
no effect.

This is consistent with the spec's "we will always overwrite color and size to
the preset body style" requirement. However, it **also** force-overrides the
per-element allowlist preservation (an author using Arial — which is on the
allowlist — will still be rendered in Lexend). That trade-off is removed once
the source-doc CSS normalization pass (Q6) ships and strips the inline style
attributes per-element; at that point the `!important` modifiers can be
removed.

Also delivered in this slice: Lexend loaded via Google Fonts `@import` (per
user choice on Q5 — answered for this phase only; full Q5 stays open).

### R4. Google Doc export defaults — parallel stylesheet shipped
Before this slice, `app/views/layouts/gdoc.html.erb` referenced `gdoc.css`
via `inlined_asset('gdoc.css')` but **no such file existed and the build
chain didn't compile one** — Gdoc exports shipped with zero LCMS-applied
styling. This slice adds:

- `app/assets/stylesheets/gdoc.scss` with the same design tokens as
  `pdf.scss` (Lexend body, H1–H6, image caption, material tag, italic).
- A new compile entry and `build:css:prefix:gdoc` step in `package.json`.

Key deviations from `pdf.scss`:

- **No Google Fonts `@import url(...)`** — Google Drive's HTML→Gdoc import
  doesn't reliably honor it. Lexend is recognized as a native Google Fonts
  family in Google Docs, so naming it in `font-family` is enough.
- **No `@page` rule** — Google Docs ignores page-setup from imported HTML.
- **`o-ld-image__caption`** (used by the Gdoc image template) is targeted in
  addition to `figcaption`.

Known caveat (tracked as Q-Gdoc-inline below): Google Docs' HTML import
honors **tag selectors** reliably but is inconsistent with **class
selectors**. So `.o-ld-material`, `.o-ld-image__caption`, etc. may not
survive into the rendered Gdoc. For class-driven styling we'd need to
inline `style="..."` directly in the `lib/doc_template/templates/gdoc/*`
renderers.

### Q-Gdoc-inline. Inline styles for class-driven Gdoc rules
Google Docs' HTML import doesn't reliably apply class selectors. Decide:

- (a) Accept that class-based rules (material tag italic, image caption
  formatting, etc.) may not appear in the Gdoc until authors manually
  re-style; rely only on tag-targeted defaults.
- (b) Update the Gdoc renderers in `lib/doc_template/templates/gdoc/` and
  `lib/doc_template/tags/material_tag.rb` (and others) to emit inline
  `style="font-style: italic; ..."` so the styling survives import.

Option (b) is more reliable but adds duplication between the stylesheet
and the template emitters.

### R5. Source-doc analysis: "Copy of LCMS Core Styling Designs Lesson Portrait"
Source: Google Doc `1xR70p8EzqKGKvjEImIKgDTKEkCdIrSJWtw7jiqzaKZk`.

**Confirmed by inspection** (all 180 inline `font-family` declarations are
Lexend; the only colors are `#000000`, `#434343`, and 2 link colors):

| Element | Doc value | Spec value | Match |
| --- | --- | --- | --- |
| Body | Lexend 11pt #000 lh 1.15 | same | ✅ |
| H1 | Lexend 22pt bold #000 padding-bottom 6pt | same | ✅ |
| H2 | Lexend 18pt bold #000 padding-bottom 6pt | same | ✅ |
| H3 | Lexend 14pt bold #434343 padding-bottom 4pt | same | ✅ |
| H4–H6 | not exercised in this doc | (defined in spec) | unverified |
| Material refs | italic spans | "italicized" | ✅ |
| Highlighting | none | default-off | ✅ |

The H1–H3 numbers in `pdf.scss` / `gdoc.scss` therefore already match the
intended visual. Remaining work is structural (header banner, standards
line, tables, vocabulary line), not typographic.

### R6. Slice plan (post-analysis decisions)

Decisions captured from user Q&A on 2026-05-27:

1. **Brandmark scope** → system-wide setting (admin Settings). Single
   upload, reused for every lesson PDF/Gdoc.
2. **Estimated-time field** → new `estimated-time` (text) field on
   lesson-metadata. Author writes free-form (e.g. "2 Class Periods").
3. **Standards display** → only the **header strip** under H1 changes to a
   bare comma-separated list. Inline `[standard: ...]` tags inside the
   body keep their existing dropdown behavior.
4. **Callout shape** → keep both the existing 3-row `callout_tag` shape
   (legacy) AND add a new 1-row 2-col variant (matches the design
   mockup). Authors can use either.
5. **Materials toggle UI** → remove entirely. PDF/Gdoc/web all render the
   materials table as a plain table without expand/collapse.
6. **Vocabulary inline** → new `vocabulary` (comma-separated text) field
   on lesson-metadata for the lesson-level inline line. Activity-level
   `vocabulary` field stays as-is for activity context.

**Slices (each a separable PR):**

- **Slice 1 — Lesson header banner.** New Settings setting for brandmark;
  new `estimated-time` and `vocabulary` fields parsed off lesson-metadata;
  rewrite `_header.html.erb` (PDF + Gdoc) to emit the
  brandmark+lesson-type+estimated-time strip → `<hr>` → `<h1>` → bare
  comma standards. New SCSS for the banner.
- **Slice 2 — Standards header rendering.** Bare comma list (no
  "Standards:" prefix, no dropdown). Splits cleanly from slice 1 only if
  we want to ship the banner first.
- **Slice 3 — Callout 1-row variant.** Extend `callout_tag.rb` to detect
  shape and dispatch to either the legacy 3-row parser or the new 1-row
  parser. New PDF + Gdoc templates for the 1-row form. New SCSS.
- **Slice 4 — Materials plain table.** Replace `materials.html.erb` with
  a plain 5-row 2-col table (label / value). Remove the toggle UI and
  the `o-ld-materials__toggler` JS. New SCSS rules for the table.
- **Slice 5 — Lesson-level vocabulary line.** Render the "Vocabulary:
  ..." line from the new lesson-metadata field, between the Overview
  block and the next H2.
- **Slice 6 — Overview block.** Render the H2 Overview + 3-bullet list
  from `description-past` / `description` / `description-future`
  metadata. Depends on slice 1 (header strip) being in place.
- **Slice 7 — H4/H5/H6 verification.** Get a second source doc that
  actually uses these levels; visually verify the spec values render
  correctly.

**Out of scope for this initiative** (existing R1):
- PrinceXML renderer (separate plugin/PR).
- Image alt-text policy (Q4 below).
- Other spec gaps tracked under Q1, Q3, Q7.

### R10. Slice 9 — Lesson footer (R2 design) implemented
PDF footer ([app/views/documents/pdf/_footer.erb](app/views/documents/pdf/_footer.erb))
rewritten to the R2 layout:

```
© <copyright_text>
─────────────────────────────────
<Grade N/Course • Unit Title • Lesson N>          <page#>   (bold)
```

- **`copyright_text`** is a new free-form `Setting` (Documents group) —
  authors type the full line, e.g. `© Acme Corp, Spring 2026`.
- **Breadcrumb** is computed by `DocumentPresenter#footer_breadcrumb`:
  `Grade {N}/Course • {unit title} • Lesson {N}`. Unit title comes from
  `document.resource.ancestors.find(&:unit?).title`, falling back to
  `Unit {unit_id}` if the resource graph isn't populated.
- **PDF**: a new `pdf_plain.scss` (previously empty) provides Lexend +
  the footer block styles. Grover renders the footer template via a
  separate Chromium document, so styles must live there, not in
  `pdf.scss`.
- **Gdoc**: `DocumentPresenter#gdoc_footer` still returns the original
  2-row shape (`{attribution}` placeholder + value). The value now
  merges `copyright_text` with `cc_attribution` (joined by ` — `) so
  the publisher copyright shows up in the Gdoc footer; the breadcrumb
  line does **not** land in Gdocs yet.

  **Why not the expanded 6-row payload?** Initial implementation passed
  three placeholders (`{attribution}`, `{copyright}`, `{breadcrumb}`).
  Deployed to staging, this caused `DocumentGdocJob` to hang during
  Apps Script post-processing — the external Apps Script function
  expects the original argument arity and chokes on the extra rows,
  combined with `Retriable.retriable(base_interval: 5, tries: 10)` in
  `app/services/google/script_service.rb` it appears as a multi-minute
  job hang. Until the Apps Script template doc in Drive is updated to
  use new placeholders AND the script can accept the extra args, the
  Ruby side must keep the 2-row shape.

  **Path to full Gdoc parity**: (1) update the Apps Script function
  outside this repo to accept additional `[placeholder, value]` pairs
  variadically and to map `{copyright}` / `{breadcrumb}` into the
  footer template, (2) update the Drive template doc with the new
  placeholders, (3) extend `gdoc_footer` again. Until then, treat the
  Gdoc footer as a PDF-only feature.

A new `_text.html.erb` partial under `app/views/admin/settings/show/`
backs the new `:text` Settings field type so admins can edit
`copyright_text` from `/admin/settings`.

### R11. Slice 10 — Lesson Materials summary aggregator
`DocumentPresenter#materials_summary` walks `Document#activity_metadata`
(JSONB column populated at import time by
[lib/lt/lcms/metadata/service.rb:50](lib/lt/lcms/metadata/service.rb#L50))
and aggregates each activity's material fields into the 5 canonical
buckets the spec mockup shows:

| Row | Source field |
| --- | --- |
| Individual Student Materials | `activity-materials-student` |
| Pair Materials | `activity-materials-pair` |
| Small Group Materials | `activity-materials-group` |
| Class Materials | `activity-materials-class` |
| Teacher Materials | `activity-metadata-teacher` |

Each row dedupes within its bucket and joins with `, `. Empty rows
render as **None** (matching the mockup). The whole block is skipped if
the document has no `activity_metadata` at all (e.g., during early
import or for material documents).

Rendered above the activities by both `documents/pdf/_header.html.erb`
and `documents/gdoc/_header.html.erb`, right after the inline
Vocabulary line. SCSS adds `.c-lesson-materials__*` rules: full-width
table, 1pt cell borders, 30% left column for labels, body-text for
values.

**Material tag tokens are resolved** (post staging QA fix): a regex pass
in `DocumentPresenter#resolve_material_tokens` strips
`[material: <id>]` brackets and, when the referenced `Material` record
exists, wraps the identifier in `<a class="o-ld-material">` (italicized
via SCSS, matching how the inline `MaterialTag` renders). Unknown
identifiers fall through to plain text without brackets.

### R12. Slice 9/10 staging fixes
Two issues showed up after the first staging QA pass and were patched:

1. **`DocumentGdocJob` hung at Apps Script post-processing.** The
   expanded `gdoc_footer` (3 placeholders) confused the external Apps
   Script function and, with `Retriable.retriable(base_interval: 5,
   tries: 10)`, the job appeared stuck for minutes. Reverted
   `gdoc_footer` to the original 2-row shape but merged
   `copyright_text` into the `{attribution}` value so the publisher
   copyright still lands in the Gdoc footer. The breadcrumb line
   remains a PDF-only feature until the Apps Script template doc and
   function are updated externally.

2. **Empty bordered rectangle below the Materials block in Gdoc.** The
   new activity template emitted `<hr class="o-ld-activity__divider">`
   above each activity heading. Google Drive's HTML→Gdoc importer
   converted that styled `<hr>` into a 1-row full-width bordered
   table, producing a phantom empty rectangle. Removed the `<hr>` from
   the **Gdoc** activity template; activities now flow with margin
   spacing only. The PDF template keeps the `<hr>` (Chromium handles
   it correctly).

### R9. Slice 8 — Activity rendering refactored to flowing layout
The legacy `activity.html.erb` (PDF) and `gdoc/activity.html.erb` (Gdoc)
templates wrapped each `activity-metadata` block in a bordered
`<table class="o-simple-table cs-bg--math-activity-bg">` with a
subject-colored bar, an UPPERCASE kicker (`activity-type`), title row,
and a separate time cell. That table-box design came from the older
math-curriculum conventions and didn't match the spec mockup.

Slice 8 replaces both templates with a flowing layout:

- `<hr>` divider between activities.
- `<h3>` heading: `{activity-title} ({time} minutes)` — `Optional:`
  prefix when `activity-label = optional`.
- Meta line: `{activity-type} ({student-grouping})` when present
  (e.g. "Discussion (Whole Class)").
- Materials line: `Materials: ...` aggregated from
  `activity-materials` / `-student` / `-pair` / `-group` / `-class`
  (comma-joined, blanks dropped).
- Metacognition / Guidance / Standards rendered as plain paragraphs.
- Body content (`@tmpl[:content]`) passes through unchanged.

SCSS lives under `.o-ld-activity__*` in `pdf.scss` and `gdoc.scss`
(plain margins; the guidance block gets a thin left border so it still
reads as a callout-style block without a colored background).

Side effect: this also masks the pre-existing **"type / text"
bleed-through bug** in the activity-metadata parser. The legacy template
emitted the unconsumed rows inside its `<table>`; the new template
doesn't render those raw rows at all because it only reads the parsed
attributes. The underlying parser bug in
`lib/doc_template/tables/activity.rb` is still latent and worth fixing
separately, but it no longer affects rendered output.

**Risk**: any curriculum or plugin that relied on the legacy
`.o-ld-activity-wrapper > table.cs-bg--math-*` markup or class names
for additional styling (e.g. dese-lcms) will need to update its styles.
The data-id / data-tag / anchor / data-optional attributes are
preserved on the new wrapper div.

### R7. Slice 4 discovery — Materials toggle was dead code, materials section is author-authored
While implementing slice 4 ("Materials plain table"), inspection revealed:

- The `o-ld-materials__toggler` collapse/expand markup in
  `lib/doc_template/templates/materials.html.erb` had **no JavaScript or
  CSS** anywhere in the codebase to make it work.
- `lib/doc_template/tags/materials_tag.rb#parse` calls
  `content_until_break(node)` and **discards the result** — the template
  was never actually rendered. The `TEMPLATE = "materials.html.erb"`
  constant was unused.
- The materials_tag spec only asserts that the section between
  `[materials]` and the next stop tag is **stripped**, with no rendered
  output verified.

Conclusion: today's `[materials]` tag strips content; the "Materials"
section shown in the source-doc mockup is **hand-authored HTML in the
Google Doc** (an H2 heading + a 2-column table the author types). That
flows through the renderer unchanged.

Slice 4 therefore reduced to dead-code cleanup:
- Deleted `lib/doc_template/templates/materials.html.erb`.
- Removed the unused `TEMPLATE` constant from `MaterialsTag`.

### R8. Slice 3 — Callout 1-row variant authoring convention
The legacy callout shape is preserved verbatim (3 rows: marker → header →
content, rendered by `lib/doc_template/templates/callout.html.erb`).

The **new 1-row 2-column shape** is detected automatically by row count
and dispatched to the new inline templates
(`callout_inline.html.erb` for PDF, `gdoc/callout_inline.html.erb`).
Layout: icon+label cell on the left, content cell on the right, separated
by a vertical rule.

Authoring convention for the 1-row shape:

| Col 1 (label)                | Col 2 (content)                 |
| ---------------------------- | ------------------------------- |
| `[callout: <subject>]` + the visible icon + label text, each on its own paragraph in the cell | The callout body (HTML preserved) |

The `[callout: <subject>]` marker is stripped from the rendered cell, so
the visible output is the icon + label only. The subject (e.g. `math`,
`science`, `ela`) is applied as a CSS modifier class on the wrapper for
subject-colored borders/icons.

**Implementation**: `CalloutTag#inline_shape?` checks `tr` count;
`fetch_content` preserves col 1 `inner_html` for the inline shape so the
icon-above-label paragraphs survive into the rendered output.

If authors prefer not to type the marker into the label cell, the
shape-detection logic can be moved up (e.g., into the Template's tag
discovery), but that's outside the scope of slice 3.

### Q-Materials-aggregator. (New) Materials table aggregator
The spec's Materials section design implies a structured 5-row table
(Individual / Pair / Small Group / Class / Teacher). Today this requires
authors to hand-author a `<table>` in the Google Doc. The
activity-metadata schema already has the source fields:
`activity-materials-student`, `activity-materials-pair`,
`activity-materials-group`, `activity-materials-class`, and
`activity-metadata-teacher`.

**Decision required**: should the LCMS aggregate those activity-level
fields into a per-lesson Materials table, rendering it automatically? If
so, this is a new tag/feature (a separate slice from the styling work),
not part of slice 4.

---

## Open questions

### Q1. H1 vs H2 when bundling individual assets
The spec itself raises this as open: "How to handle H1 versus H2 when bundling
individual assets? (e.g., Acknowledgements and materials that get bundled into
a single document?)"

**Decision required**: when an asset that owns its own H1 is embedded into a
bundle that also has an H1 (front matter / acknowledgements), do we
(a) demote the asset's H1 to H2, (b) keep both H1s and rely on TOC structure,
or (c) something else?

Affects: bundle front-matter implementation, TOC, and any heading-based
navigation in PDF/Gdoc exports.

### Q2. Header / footer defaults for Materials and Bundles
The Lesson footer (R2) is confirmed. Still need:

- **Header** for Lesson documents — the spec says "we will provide sensible
  defaults" but does not define what they are. Provide a design or confirm
  "no header" as the default.
- **Material** footer/header — the current code reuses the same footer template
  as documents. Should Materials match Lesson footer (R2) or have their own
  design (e.g., different metadata: Unit / Section / Material title)?
- **Bundle** footer/header — likely needs a different layout because each
  embedded asset would otherwise need its own footer string. Provide design.
- **Gdoc constraint**: Google Docs cannot switch header/footer mid-document.
  What's the policy when a phase or per-asset footer is desired in a Gdoc
  export? Pick one footer or split into multiple Gdoc files?

### Q3. Bundle front matter, divider pages, blank pages
The spec links a design doc ("LCMS Core Styling Designs Bundle Front Matter")
but the text in the spec does not describe the actual layout. Need:

- Bundle front matter layout (cover-page design, fields, branding).
- Divider page layout (what triggers one, what it contains).
- "Purposefully blank" page layout (text shown, when inserted — e.g., before
  duplex section start).

These are needed before the bundle-styling phase can be built.

### Q4. Image alt tags
Listed under Accessibility in the spec, no concrete requirement. Need:

- Where does the alt text come from? (image `alt` attribute carried through
  from the source Google Doc, a separate metadata field, or both?)
- Failure mode when alt text is missing — block export, warn, or silently
  emit empty `alt=""`?
- Does this also apply to icons and decorative images, or only content
  images?

### Q5. Font delivery for Lexend
The default body font (Lexend) is not a Chromium built-in. Choose one:

- **Self-host**: ship Lexend WOFF2 files in `vendor/` or `node_modules`,
  reference via `@font-face`. Works offline and with the existing base64
  asset-embed pipeline.
- **Google Fonts CDN**: `@import` from `fonts.googleapis.com`. Simpler but
  needs network at PDF-render time and may not coexist with
  `ENABLE_BASE64_CACHING`.

Same question applies to the allowlisted alternates (Arial, Nunito, Roboto,
Tahoma, Verdana) — Arial/Tahoma/Verdana are typically system fonts and may
not be present in the Chromium PDF environment.

### Q6. Scope of the source-doc CSS normalization pass
The spec requires that exports **override** color and size from source docs,
**replace** non-allowlist font families with the body style, and **strip**
text highlighting by default. Today, `DocTemplate::Template#parse`
(`lib/doc_template/template.rb:84`) sanitizes the Google-Doc `<style>` block
and passes it through verbatim via `@document.css_styles`.

**Decision required**: is the normalization pass part of this initiative, or
is it a separate ticket? If part of this work:

- Implement as a post-sanitization pass over `css_styles` (regex/CSS parser),
  or as an inline transformation on style attributes in the rendered body?
- Which approach is acceptable to the team given the existing sanitizer
  pipeline?

### Q7. Tag styling details — incomplete in spec
The spec lists the following tags but only Callouts and Images have full
specifications:

- Material tag — "Normal text, but italicized" (clear)
- Icons — not specified
- Callouts — visual example given (clear enough)
- Page break — not specified (CSS `page-break-before: always`?)
- Line (horizontal rule) — not specified (weight, color, spacing?)
- Checkbox (clickable) — not specified (size, behavior in PDF vs Gdoc?)
- Video (URL) — not specified (link only? preview thumbnail? icon?)
- Heading — covered by H1–H6 defaults
- Line break — not specified (different from paragraph spacing?)
- Images — specified (clear)
- Answer (teacher version only) — not specified visually (highlighted box?
  inline italic? different color?)
- Thumbnail — not specified (size, alignment, caption rules?)

For each unspecified tag: need a visual design or "use sensible default and
review later" sign-off.

### Q8. Initiative-level scoping
The spec text mixes engineering work with non-engineering items
(cost model, IP ownership in the "To Discuss" section). For the engineering
portion, propose splitting into the following tickets so they can be reviewed
and shipped independently:

1. Core SCSS defaults (Lexend body, H1–H6, page setup, image caption/credit,
   wire the dangling BEM classes already referenced in views).
2. Source-doc CSS normalization (Q6).
3. Tag styling pass (Q7).
4. Bundle styling — front matter, dividers, blank pages (Q3).
5. Heading-collision rule for bundling (Q1).
6. Image alt-text handling (Q4).

Confirm whether to ship as a single PR or split per above.

### Q9. `config/pdf.yml` `handout` profile
The spec mandates 0.5" margins as the default. The current `handout` profile
in `config/pdf.yml` uses 1.25" margins, which contradicts the spec. Is the
`handout` profile being retired, kept as a customization escape hatch, or
should it be updated to the new defaults?
