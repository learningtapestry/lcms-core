# frozen_string_literal: true

#
# Presents a unit Resource for the admin and as an exportable unit document
# (Exporters::Pdf::Unit / Exporters::Gdoc::Unit). The unit document currently
# holds the Teacher Edition cover page; further unit pages are appended to it.
#
class UnitPresenter < ContentPresenter
  include HasGdocSource

  # Admin-managed cover fields (Admin::UnitsController#update). Stored in the
  # unit's metadata JSONB beside the imported unit-metadata rows:
  # UnitResourceUpsertService deep-merges the imported keys and drops blank
  # values, so a reimport keeps these.
  COVER_IMAGE_KEY = "cover_image_url"
  COVER_CREDIT_KEY = "cover_image_credit"

  delegate :acknowledgements, :copyright, :course, :description, :license,
           :unit_id, :unit_title_spanish, :unit_topic, :unit_topic_spanish, :version,
           to: :base_metadata

  def base_filename(**)
    s3_folder
  end

  def bundle_folder(bundle_type = nil)
    folder = "#{BUNDLE_S3_FOLDER}"
    folder += "/#{bundle_type}" if bundle_type.present?
    "#{folder}/#{s3_folder}"
  end

  # Cover image credit line ("iStock.com / Hakase_"), or nil when none is set.
  def cover_image_credit
    metadata[COVER_CREDIT_KEY].to_s.strip.presence
  end

  # Cover image for both exports, inlined as a data URI so it survives the
  # HTML→Gdoc import without Google having to fetch it (same approach as
  # ContentPresenter#brandmark_url). Falls back to the stored URL if inlining
  # fails. Nil when no cover image has been uploaded.
  def cover_image_url
    raw = metadata[COVER_IMAGE_KEY].presence
    return if raw.nil?

    AssetHelper.inline_data_uri(raw, cache: ViewHelper::ENABLE_BASE64_CACHING) || raw
  end

  # The Copyright page is only rendered when the unit authors either row.
  def copyright_page?
    copyright.present? || license.present?
  end

  # Bundled-document footer, first line: "<copyright>, <version>".
  def footer_copyright
    [copyright, version].compact_blank.join(", ").presence
  end

  # Bundled-document footer, second line: "<course> • <unit title>".
  def footer_breadcrumb
    [course, unit_title].compact_blank.join(" • ").presence
  end

  # The unit document is the head of the Teacher Bundle to Print, so its Google
  # Doc takes the bundled-document header/footer from a dedicated template
  # (GOOGLE_APPLICATION_TEMPLATE_BUNDLE) rather than the lesson one. Its
  # placeholders: {brandmark_url} and {course} in the header; {cc_logo},
  # {bundle_copyright} and {bundle_breadcrumb} plus a page number field in the
  # footer. See Google::ScriptService#parameters for the positional contract.
  def gdoc_footer
    [["{bundle_copyright}", "{bundle_breadcrumb}"], [footer_copyright, footer_breadcrumb]]
  end

  def gdoc_header
    [["{course}"], [course]]
  end

  def gdoc_template_id
    ENV["GOOGLE_APPLICATION_TEMPLATE_BUNDLE"].presence ||
      raise(KeyError, "GOOGLE_APPLICATION_TEMPLATE_BUNDLE is not set: the Teacher Bundle to Print Google Doc needs " \
                      "the bundled-document template (see docs/env-variables.md)")
  end

  # Page 1 is the cover, which has no running header or footer (its logo and
  # rule are drawn in the page body): the Apps Script turns on Google Docs'
  # "different first page" and leaves the first-page header/footer empty.
  def gdoc_distinct_first_page?
    true
  end

  def gdoc_folder
    s3_folder
  end

  # Lessons in curriculum order (a preorder walk of the tree by level_position:
  # section 1's lessons, then section 2's, ...), so anything collected across
  # them reads in the order a teacher meets them. Not hierarchical_position,
  # which is computed once at save and goes stale when siblings are reordered.
  def lessons
    @lessons ||= self_and_descendants_preordered.lessons.with_documents
                   .map { DocumentPresenter.new(it.document) }
  end

  def materials
    unit_bundle_interactor.materials
  end

  # The Unit Overview page carries the description and the Unit Standards.
  def overview_page?
    description.present? || standard_codes.any?
  end

  def pdf_filename
    "#{base_filename}.pdf"
  end

  # Standard codes from the standards row of every lesson in the unit, in
  # lesson order, without duplicates (compared case-insensitively; the first
  # spelling wins). Spec "LCMS Core Unit > Unit Standards". Turning the codes
  # into grouped standards text waits on the client's standards spreadsheet.
  def standard_codes
    @standard_codes ||= lessons.flat_map do |lesson|
      lesson.standards.to_s.split(DocTemplate::Tables::Base::SPLIT_REGEX).map(&:squish).compact_blank
    end.uniq(&:upcase)
  end

  # Materials named in the unit-metadata unit-materials row, in authored
  # order, for the Unit Materials pages of the Teacher Bundle to Print
  # (Acknowledgements, ...). Distinct from #materials, which is every material
  # whose metadata places it in this unit.
  def unit_materials
    @unit_materials ||= Material.in_listed_order(base_metadata.unit_materials).map { MaterialPresenter.new(it) }
  end

  # The Acknowledgements page(s) of the Teacher Bundle to Print: the unit
  # material(s) whose material-title is "Acknowledgements", placed right after
  # the Copyright page rather than with the other Unit Materials.
  def acknowledgements_materials
    unit_materials.select { acknowledgements?(it) }
  end

  # Unit Materials pages of the Teacher Bundle to Print (after the Unit
  # Overview): every unit material except the Acknowledgements.
  def bundle_unit_materials
    unit_materials.reject { acknowledgements?(it) }
  end

  def unit_title
    base_metadata.unit_title.presence || title
  end

  # The unit's number when its metadata reads "unit 3" ("3"); nil for unit
  # ids such as "m6u1a", which carry no reliable number.
  def unit_number
    metadata["unit"].to_s[/\Aunit\s*(\w+)\z/i, 1]
  end

  # Sections of the unit in curriculum order.
  def sections
    @sections ||= self_and_descendants_preordered.sections.map { SectionPresenter.new(it) }
  end

  def s3_folder
    Breadcrumbs.new(self).short_pieces.join("_")
  end

  private

  # "Acknowledgements" or the "Acknowledgments" spelling, any case.
  def acknowledgements?(material)
    material.title.to_s.squish.downcase.in?(%w(acknowledgements acknowledgments))
  end

  def base_metadata
    @base_metadata ||= DocTemplate::Objects::Unit.build_from(metadata)
  end

  # TODO: why we use interactor? shouldn't it be a Query?
  def unit_bundle_interactor
    @unit_bundle_interactor ||= UnitBundleInteractor.call(self)
  end
end
