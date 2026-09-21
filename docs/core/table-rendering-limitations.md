# Authored Table Rendering — Known Limitations

How author-authored content tables (the tables an author draws inside a Google
Doc lesson/material, *not* the metadata tables like `material-metadata`) are
processed before they reach the PDF and Gdoc outputs, and what is lost along
the way.

The pipeline: Google Doc HTML → `HtmlSanitizer` (allow-list of elements,
attributes, and CSS properties + a few transformers) → per-context
post-processing → rendered by `pdf.scss` / `gdoc.scss`. A style survives only
if it is on an allowed element, is an allowed attribute, is an allowed CSS
property, and is not overridden by an `!important` app rule.

Verified against the code on branch `76-styling-lessons-materials`
(2026-06-26). See [styling-defaults-needs-clarification.md](styling-defaults-needs-clarification.md)
Q7 for related open tag-styling questions.

**Status (2026-06-26):** L1, L2, L3, and L4 have been addressed for material
content (each section below notes the fix). L5 and L6 remain open.

## Limitations

### L1. Authored text color is stripped
Cell text keeps no authored color — colored text (e.g. red numbers) renders in
the default near-black body color. Two layers remove it:

- `color` is **not** in the sanitizer's allowed CSS `properties` list
  (`app/services/html_sanitizer.rb:128-130`), so every `color:` declaration is
  dropped. `remove_meanless_styles` additionally strips `color:#000000`
  explicitly (`html_sanitizer.rb:169`).
- `pdf.scss` / `gdoc.scss` then force `td, th { color: $color-text !important }`
  (`app/assets/stylesheets/pdf.scss:36-41`), which would override any inline
  color even if it survived the sanitizer.

**Impact:** authored emphasis-by-color in tables is lost. (Background
*highlight* is intentionally stripped per spec; text color is a separate case
and currently shares the same fate.)

**Addressed (materials, 2026-06-26):** `color` is now an allowed CSS property
(`html_sanitizer.rb`), and `pdf.scss` no longer force-sets `color !important`
globally — the brand-color enforcement is re-scoped to the lesson wrapper
`[class*="o-page--cg-"]`. Material content (`.o-m-content`, which has no lesson
wrapper) therefore keeps authored text color, while lessons stay normalized.
Gdoc material color rides on the now-preserved inline style into the Google Doc
import (the gdoc stylesheet is unchanged). Caveat: lesson content rendered
without the `o-page--cg-` wrapper (e.g. some bundle paths) would no longer be
force-normalized — verify if those paths matter.

### L2. `<th>` header cells lose all inline styling; `<td>` does not
The sanitizer attribute allow-list (`html_sanitizer.rb:119-120`) permits
`style` on `td` (`colspan rowspan style`) but **not** on `th`
(`colspan rowspan` only). So a header cell authored as `<th>` drops its
background, borders, alignment, width, and height, while the identical content
in a `<td>` keeps them.

**Impact:** header-row styling is reliable only when Google Docs exports the
cells as `<td>`. A real `<th>` header flattens.

**Addressed (2026-06-26):** `style` was added to the `th` attribute allow-list
(`html_sanitizer.rb`), so header cells now keep their inline
background/border/alignment like `td`. Global change (lessons benefit too).

### L3. Content tables have no house styling
The sanitizer tags content tables `.c-ld-table` (and adds
`o-native-table` / `u-table-padding` in the Gdoc context), but **none of those
classes have any SCSS** — confirmed no rules in `pdf.scss`, `gdoc.scss`, or
`pdf_plain.scss`. See `post_processing_tables` / `post_processing_tables_gdoc`
(`html_sanitizer.rb:357-368`).

**Impact:** an arbitrary content table gets borders, cell padding, and header
background **only** from authored inline styles. There is no fallback border,
no default cell padding, and no wide-table overflow handling.

**Addressed (materials, 2026-06-26):** `pdf.scss` now gives
`.o-m-content .c-ld-table` a baseline border + cell padding. Every declaration
is non-`!important`, so authored inline borders/padding/alignment still win;
only un-styled tables fall back to the house default. (Still no wide-table
overflow handling — see L5.)

### L4. Pinned header row is not guaranteed to repeat across page breaks
There is no `thead { display: table-header-group }` rule and no logic that
promotes the first row to a repeating header. Repetition depends entirely on
Google Docs exporting a real `<thead>` and Chromium's (Grover's) default
behavior. A header authored as a plain `<tr>` will not reappear at the top of a
continued page.

**Impact:** "pinned header row" tables that span a page break may show the
header only on the first page.

**Addressed (materials, 2026-06-26):** `pdf.scss` adds
`.o-m-content thead { display: table-header-group }`, which makes Chromium/Grover
repeat the header on each page. Caveat: this only helps when Google Docs exports
the pinned row inside a `<thead>`; a header authored as a plain `<tr>` would
still need post-processing promotion (not done).

### L5. Material/handout tables skip the table wrapper
`post_processing_tables` wraps tables in `.c-ld-table__wrap`
**`unless @options[:material]`** (`html_sanitizer.rb:357-362`), so material
(handout) tables never receive the wrapper.

**Impact:** harmless today because `.c-ld-table__wrap` is unstyled (L3), but any
future wrapper-based fix (e.g. overflow/scroll for wide tables) will not reach
materials unless this is revisited.

### L6. Border zero-width normalization skips `th` and `thead`
`replace_table_border_styles` only iterates `tbody/tr/td`
(`html_sanitizer.rb:387+`) when collapsing authored zero-width borders to
`border-*:0`. Borders on `th` cells or rows directly under `thead` are not
normalized.

**Impact:** minor; inconsistent border cleanup between body and header cells.
Now slightly more reachable since L2 lets `th` carry inline borders — a
zero-width border on a header cell won't be normalized. Still low priority.

## What is preserved (works today)

- **Merged cells** — `colspan` / `rowspan` are kept on both `td` and `th`.
- **Borders** — `border-bottom/left/right/top` (width, color, style) are
  allowed CSS properties, so a custom or colored cell border survives on `<td>`.
- **Cell background** — `background-color` is allowed, so a gray header
  background survives on `<td>`.
- **Text alignment** — `text-align` is an allowed property and the
  `[table-preserve-alignment]` tag also promotes inline alignment to classes.
- **Row height / cell width / vertical-align** — allowed properties.
- **Inline italics / bold** — `font-style` / `font-weight` are allowed.

## Caveat: source vs. rendered output

Several limitations (L1 especially, and the read on L4) only become visible in
the **rendered** PDF/Gdoc, not in the authored Google Doc. A screenshot of the
source doc will still show red text and native pinned headers; the loss happens
during sanitization/rendering. Confirm behavior against an actual export, not
the source document.
