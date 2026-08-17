# frozen_string_literal: true

class DocumentPresenter < ContentPresenter
  include Rails.application.routes.url_helpers

  delegate :cc_attribution,
           :grade,
           :lesson_title, :lesson_number, :lesson_type, :section_number, :subject, :unit_id,
           :teaser,
           to: :base_metadata

  # A single class period is 45 minutes; the banner "Estimated Time" rounds
  # the lesson's total activity time up to whole class periods.
  CLASS_PERIOD_MINUTES = 45

  MATERIALS_ROWS = {
    "Individual Student Materials" => "activity-materials-student",
    "Pair Materials" => "activity-materials-pair",
    "Small Group Materials" => "activity-materials-group",
    "Class Materials" => "activity-materials-class",
    "Teacher Materials" => "activity-materials-teacher"
  }.freeze

  # current key => key it was authored under before the rename. Documents keep
  # their parsed activity_metadata forever, so a lesson imported before
  # `activity-metadata-teacher` became `activity-materials-teacher` still stores
  # the old key and would otherwise report "None" for Teacher Materials.
  # (DocTemplate::Objects::Activity.apply_defaults does the same for the
  # per-activity "Materials:" line.)
  LEGACY_MATERIALS_KEYS = { "activity-materials-teacher" => "activity-metadata-teacher" }.freeze

  def copyright_text
    Settings.get(:documents, include_defaults: true)&.dig(:copyright_text).presence
  end

  # Converts a lesson's stored `lesson-type` abbreviation (e.g. "AP") into its
  # full label (e.g. "Anchoring Phenomenon") using the client-configurable
  # Settings lesson_types map (see admin Settings > Documents). Each LCMS
  # instance defines its own abbr => label list, so the lookup is
  # case-insensitive and falls back to titleizing the abbreviation when it
  # isn't in the map — preserving the prior behavior for unmapped values.
  def lesson_type_label
    Settings.map_label(:lesson_types, lesson_type)
  end

  # Title of the lesson's unit, shown in the lesson header (PDF banner strip and
  # Gdoc running header) and in the footer breadcrumb. Prefers the authored
  # unit-metadata title, falls back to the unit Resource's title, then to
  # "Unit {id}". Blank when the document has no unit ancestor and no unit_id.
  def unit_title
    unit_metadata&.unit_title.presence ||
      unit_resource&.title.presence ||
      (unit_id.present? ? "Unit #{unit_id.to_s.upcase}" : nil)
  end

  # First-page H1 for both exports (PDF banner and Gdoc body): the lesson title
  # prefixed with its lesson number — e.g. "Lesson 5: How does our stuff impact
  # climate change?". Falls back to the bare title when the lesson has no
  # number, and to the bare "Lesson N" when it has no title, so neither side of
  # the separator can render alone with a dangling colon. Distinct from the Gdoc
  # RUNNING header's {title}, which stays unprefixed (see #gdoc_header).
  def banner_title
    [lesson_label, lesson_title.presence].compact_blank.join(": ")
  end

  # Footer line 1: boilerplate copyright/company text (Settings) with the unit
  # version appended — e.g. "© Company Name, v1.0".
  def footer_copyright
    [copyright_text.presence, unit_version.presence].compact.join(", ").presence
  end

  # Per-lesson licence/attribution authored in lesson-metadata `cc-attribution`
  # (e.g. "Adapted from OpenSciEd, CC BY-NC-SA 4.0"). Distinct from
  # #footer_copyright, which is the site-wide Settings boilerplate: this one is
  # a per-lesson legal statement, so it must survive into every export rather
  # than being replaced by the global line. Blank for lessons that set none.
  def footer_attribution
    cc_attribution.presence
  end

  # The course name, from unit-metadata. Feeds #footer_course_lesson rather than
  # a line of its own — see there.
  def footer_course
    unit_metadata&.course.presence
  end

  # Footer breadcrumb: "Course • Lesson 1 of 12".
  #
  # The course, NOT the unit title. A lesson whose unit was created implicitly
  # by the lesson import (no unit-metadata document of its own) has no authored
  # unit title, and falling back down the chain printed the importer's generated
  # resource label — e.g. "Science G10 gg" — into every exported footer.
  #
  # Blank parts drop out of the join, so a unit with no metadata at all degrades
  # to a bare "Lesson 7" instead of inventing a placeholder.
  def footer_course_lesson
    [footer_course, footer_lesson_label].compact_blank.join(" • ").presence
  end

  # "Lesson 1 of 12" — the lesson's number plus how many lessons its unit holds.
  #
  # Falls back to the bare "Lesson 1" whenever the total can't be trusted: no
  # unit ancestor, a unit whose lessons were never imported, or a count lower
  # than this lesson's own number (which happens when a lesson doc with a blank
  # `section-number` lands on a section-typed resource, leaving its unit with no
  # lesson resources at all). Better a short label than a wrong "of".
  def footer_lesson_label
    total = unit_lesson_count.to_i
    return lesson_label if lesson_label.blank? || total < lesson_number.to_i

    I18n.t("lesson.footer.lesson_of", number: lesson_number, total:)
  end

  # Aggregates activity-metadata material fields into the 5-row lesson
  # Materials summary table. Each row collects values across all
  # activities, dedupes, joins, and resolves any [material: id] tokens
  # to italicized identifier links (matching how MaterialTag renders
  # inline). A category with no materials in the lesson renders "None", so
  # the table always shows all five rows (including a lesson with no
  # activities, where every row is "None").
  #
  # @return [Hash{String => String}] heading => joined materials HTML
  #   (or "None" for an empty category).
  def materials_summary
    activities = Array.wrap(activity_metadata)

    rows = MATERIALS_ROWS.transform_values do |key|
      activities.flat_map { |a| split_list(activity_field(a, key)) }.uniq.compact_blank
    end

    # Single query for every [material: id] token across all five rows.
    known = DocTemplate::Tags::MaterialTokens.lookup(
      rows.values.flatten.flat_map { |v| DocTemplate::Tags::MaterialTokens.identifiers_in(v) }
    )

    rows.transform_values do |values|
      next "None" if values.empty?

      # These fields hold DECODED PLAIN TEXT (activity-materials-* is not in
      # Tables::Activity::HTML_VALUE_FIELDS), but both header views emit the
      # result with `raw` so MaterialTokens can inject its <span> markup.
      # Escape the authored text first — otherwise an entry like
      # "Beakers <250ml>" is parsed as a tag and silently disappears from the
      # rendered table. `[material: id]` tokens survive escaping untouched, so
      # resolution still works on the escaped string.
      values.map { |v| DocTemplate::Tags::MaterialTokens.resolve(ERB::Util.html_escape(v), known:) }
            .join(", ")
    end
  end

  def content_for(context_type, options = {})
    render_content(context_type, options)
  end

  def description
    base_metadata.description
  end

  # Banner "Estimated Time", computed from the sum of every activity's
  # activity-time at 45 minutes per class period, rounded up:
  # ≤45 → "1 Class Period", 46–90 → "2 Class Periods", etc. Falls back to the
  # authored lesson-metadata estimated-time when no activity defines a time.
  def estimated_time
    class_periods || base_metadata.estimated_time.presence
  end

  # Rich HTML for the Lesson Preparation section, sourced from the lesson-prep
  # table's `lesson-prep-directions` field (sub-headings + nested lists).
  # `[material: id]` tokens are resolved to inline identifier links (same as the
  # Materials summary and activity Materials line), so a slide/worksheet
  # reference renders identically here instead of showing the raw tag.
  # Blank when the lesson defines no preparation directions.
  def lesson_prep_directions
    @lesson_prep_directions ||=
      DocTemplate::Tags::MaterialTokens.resolve(base_metadata.lesson_prep&.lesson_prep_directions)
  end

  # "Lesson Preparation (30 minutes)" — the section heading carrying the
  # authored lesson-prep-time, mirroring how an activity heading carries its
  # activity-time. Falls back to the bare heading when the lesson-prep table
  # defines no time (or a non-positive one), so no empty parentheses render.
  def lesson_prep_heading
    heading = I18n.t("lesson.preparation.heading")
    minutes = base_metadata.lesson_prep&.lesson_prep_time.to_i
    return heading unless minutes.positive?

    I18n.t("lesson.preparation.heading_with_time",
           heading:, time: I18n.t("lesson.preparation.minutes", count: minutes))
  end

  # Overview bullet 1 — "In the previous lesson, we…", this lesson's OWN
  # `description-past`.
  #
  # All three Overview bullets come from the lesson's own lesson-metadata: the
  # author writes the recap, the summary and the look-ahead in one table, and
  # all three render in that lesson. (An earlier implementation read the recap
  # and look-ahead off the neighbouring lessons instead; that is not how these
  # documents are authored.) Blank when the field is empty, so the view drops
  # the bullet.
  def overview_past
    base_metadata.description_past.presence
  end

  # Overview bullet 3 — "In the next lesson, we will…", this lesson's OWN
  # `description-future`. See #overview_past.
  def overview_future
    base_metadata.description_future.presence
  end

  # Lesson-banner vocabulary line compiled from every activity's `vocabulary`
  # field across the lesson, de-duplicated and comma-joined. Blank when no
  # activity defines vocabulary, so the view can skip the line. Distinct from
  # the lesson-metadata `vocabulary` field (see lesson-metadata-specs.md).
  def vocabulary
    Array.wrap(activity_metadata)
      .flat_map { |a| split_list(a["vocabulary"]) }
      .uniq
      .compact_blank
      .join(", ")
  end

  # Footer data for Google Apps Script post-processing.
  # Used in Google::ScriptService#parameters.
  #
  # Mirrors the PDF footer (copyright, optional attribution, course • lesson)
  # so the generated Gdoc matches the PDF.
  #
  # STRUCTURE (see config/scripts/Code.gs#postProcessing): exactly two parallel
  # arrays — [all_placeholders, all_values] — consumed as the Apps Script's
  # footerPatterns / footerReplaceTexts args, which it loops as
  # replaceText(patterns[i], values[i]). NOT a list of [placeholder, value]
  # pairs (that mis-aligns the positional args and drops the header entirely).
  #
  # IMPORTANT: the Apps Script template doc in Drive
  # (GOOGLE_APPLICATION_TEMPLATE_PORTRAIT / _LANDSCAPE) MUST define these exact
  # placeholders in its footer — {copyright}, {course}, {unit_lesson}. The
  # template's footer is copied verbatim into the doc, then these are replaced.
  #
  # {page_number} is deliberately NOT in this list. A Google Doc page number is
  # its own PageNumber element, not text, so replaceText could only stamp one
  # fixed number onto every page; config/scripts/Code.gs#insertFooterPageNumber
  # swaps that placeholder for a live element instead.
  #
  # {course} and {unit_lesson} are legacy placeholder NAMES kept as-is because
  # they already exist in the Drive template: renaming them here would leave the
  # old literal text sitting in every generated footer until the template was
  # hand-edited. The course now rides in the {unit_lesson} breadcrumb, so
  # {course} is blanked — delete that paragraph from the template when
  # convenient and this slot becomes a no-op.
  #
  # @return [Array(Array<String>, Array<String>)] [patterns, values]
  def gdoc_footer
    [
      ["{copyright}", "{attribution}", "{course}", "{unit_lesson}"],
      [footer_copyright, footer_attribution, nil, footer_course_lesson]
    ]
  end

  # Header data for Google Apps Script post-processing.
  # Used in Google::ScriptService#parameters.
  #
  # Mirrors the banner in the PDF header (documents/pdf/_header.html.erb):
  # title, unit title, lesson type, and estimated time — substituted into the
  # template doc's running header.
  #
  # STRUCTURE (see config/scripts/Code.gs#postProcessing): exactly two parallel
  # arrays — [all_placeholders, all_values] — consumed as the Apps Script's
  # headerPatterns / headerReplaceTexts args. NOT a list of [placeholder, value]
  # pairs.
  #
  # IMPORTANT: the Apps Script template doc in Drive
  # (GOOGLE_APPLICATION_TEMPLATE_PORTRAIT / _LANDSCAPE) MUST define the exact
  # placeholders it uses in its header. `{title}` may be absent (the title also
  # renders in the body banner) — a missing placeholder is a harmless no-op, so
  # `{unit_title}` only shows up once it is added to the template header.
  # `{estimated_time}` carries the value only (e.g. "2 Class Periods"); keep any
  # "Estimated Time:" label as static text so a blank value leaves no dangling
  # label.
  #
  # @return [Array(Array<String>, Array<String>)] [patterns, values]
  def gdoc_header
    [
      ["{title}", "{unit_title}", "{lesson_type}", "{estimated_time}"],
      [lesson_title, unit_title, lesson_type_label, estimated_time]
    ]
  end

  def base_metadata
    @base_metadata ||= DocTemplate::Objects::Lesson.build_from(metadata)
  end

  #
  # NOTE: This is a placeholder for future implementation.
  #
  # Return all the materials associated with the document.
  #
  # @return [Array<MaterialPresenter>]
  #
  def materials
    []
  end

  def pdf_filename
    name = short_breadcrumb(join_with: "_", with_short_lesson: true)
    "#{name}.pdf"
  end

  def render_content(context_type, options = {})
    options[:parts_index] = document_parts_index
    rendered_layout = DocumentRenderer::Part.call(layout_content(context_type), options)
    content = DocTemplate.sanitizer.clean_content(rendered_layout, context_type)
    ReactMaterialsResolver.resolve(content, self)
  end

  def short_breadcrumb(join_with: " / ", with_short_lesson: false, with_subject: true, unit_level: false)
    lesson_abbr = with_short_lesson ? "L#{lesson_number}" : "Lesson #{lesson_number}" \
      unless unit_level
    [
      with_subject ? SUBJECTS[subject] || SUBJECT_DEFAULT : nil,
      grade.to_i.zero? ? grade : "G#{grade}",
      "U#{unit_id.to_s.upcase}",
      "S#{section_number}",
      lesson_abbr
    ].compact.join(join_with)
  end

  def short_title
    "Lesson #{lesson_number}"
  end

  def standards
    base_metadata.standards
  end

  private

  # Total activity time across the lesson, expressed in whole 45-minute class
  # periods (rounded up). Nil when no activity defines a time, so the banner
  # can fall back to the authored estimated-time.
  def class_periods
    total = Array.wrap(activity_metadata).sum { |a| a["activity-time"].to_i }
    return nil unless total.positive?

    count = (total.to_f / CLASS_PERIOD_MINUTES).ceil
    "#{count} #{'Class Period'.pluralize(count)}"
  end

  # The unit-level Resource ancestor of this lesson (populated by
  # UnitBuildService), or nil when the document has no unit ancestor.
  def unit_resource
    return @unit_resource if defined?(@unit_resource)

    @unit_resource = resource&.ancestors&.find(&:unit?)
  end

  # How many lesson Resources this lesson's unit holds, across all its sections
  # — the "of 12" in the footer breadcrumb. One COUNT query, memoized. Nil
  # without a unit ancestor.
  def unit_lesson_count
    return @unit_lesson_count if defined?(@unit_lesson_count)

    @unit_lesson_count = unit_resource&.descendants&.lessons&.count
  end

  # unit-metadata for this lesson's unit, as a DocTemplate::Objects::Unit built
  # from the unit Resource's stored metadata. Nil without a unit ancestor.
  def unit_metadata
    return @unit_metadata if defined?(@unit_metadata)

    @unit_metadata = unit_resource && DocTemplate::Objects::Unit.build_from(unit_resource.metadata)
  end

  def unit_version
    unit_metadata&.version
  end

  def lesson_label
    lesson_number.to_i.positive? ? "Lesson #{lesson_number}" : nil
  end

  # Reads an activity-metadata field, falling back to the key the field was
  # authored under before it was renamed (see LEGACY_MATERIALS_KEYS).
  def activity_field(activity, key)
    value = activity[key]
    return value if value.present?

    legacy = LEGACY_MATERIALS_KEYS[key]
    legacy ? activity[legacy] : value
  end

  # Splits an authored list cell into entries on the SAME separators the rest of
  # DocTemplate uses (Tables::Base#fetch_materials resolves `[material: id]`
  # tokens from these very cells with SPLIT_REGEX). Splitting on "," alone left
  # a semicolon-separated cell as one run-on entry, which also defeated the
  # dedupe against activities that used commas.
  def split_list(value)
    return [] if value.blank?

    value.to_s.split(DocTemplate::Tables::Base::SPLIT_REGEX).map(&:strip).reject(&:blank?)
  end
end
