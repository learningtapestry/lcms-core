# Technical Debt

Known shortcuts and leftovers, kept here so they are not rediscovered from
scratch. Each entry says what it is, why it was left, and what fixing it takes.

## Teacher Bundle to Print renders lesson and material files nothing uses

**Where:** `app/jobs/unit_bundle_pdf_job.rb`, `app/jobs/unit_bundle_gdoc_job.rb`

**What:** The Teacher Bundle to Print is a single document: `Exporters::Pdf::Unit`
and `Exporters::Gdoc::Unit` render the whole bundle (cover, front matter,
sections, lessons and their materials) from the unit's HTML templates. Both
jobs still run `generate_dependants` from before that was the case:

- `UnitBundlePdfJob` queues a `DocumentPdfJob` per lesson and a
  `MaterialPdfJob` per material (`content_type: unit_bundle`), then copies
  their PDFs into the bundle's S3 folder next to the unit PDF.
- `UnitBundleGdocJob` queues a `DocumentGdocJob` per lesson and a
  `MaterialGdocJob` per material into the bundle's Drive folder (lessons in
  the folder, materials in a `materials` sub-folder).

The unit document does not read any of these files, and nothing else reads the
`unit_bundle` links they store on lessons and materials or the copies in the
S3 folder (the admin page links the unit PDF and the unit Google Doc
directly). The individual lesson and material files a teacher needs come from
the Teacher Bundle for Digital Access and the Full Unit Content for Download.

**Cost:** Each bundle run renders every lesson and material a second time: the
PDF job spends Chromium time and S3 uploads; the Google Doc job spends Apps
Script runs and Drive calls (quota) and makes the bundle wait for all of them
before the unit document is exported.

**Why it was left:** Removing it changes what lands in the bundle folders in S3
and Drive; kept as is until that is agreed.

**Fix:** Make `generate_dependants` a no-op in both jobs (drop
`DocumentPdfJob`/`MaterialPdfJob`/`DocumentGdocJob`/`MaterialGdocJob` from
their `NESTED_JOBS`), remove `copy_pdf_to_bundle` and the `materials` folder,
and update the folder diagrams in the job comments and their specs. Existing
files in the bundle folders can be left or deleted by hand.
