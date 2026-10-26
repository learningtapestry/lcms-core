# frozen_string_literal: true

class DocumentPresenter < ContentPresenter
  include Rails.application.routes.url_helpers

  delegate :cc_attribution,
           :grade,
           :learning_targets,
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

  # Material types printed after the lesson in the Teacher Bundle to Print,
  # in the order they appear there.
  BUNDLE_MATERIAL_TYPES = %w(worksheet response reference).freeze

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

  # Lesson N Materials in the Teacher Bundle to Print: the lesson's
  # worksheets, then its responses, then its references (other material types
  # are not printed). Within a type, materials follow the order of the
  # activities that list them; within one activity, their material-order
  # (1 before 2; unnumbered last, in authored order). A material listed by
  # several activities is printed once, with the first.
  #
  # @return [Array<MaterialPresenter>]
  def bundle_materials
    @bundle_materials ||=
      listed_materials.each_with_index.filter_map do |(material, position), authored|
        metadata = DocTemplate::Objects::Material.build_from(material.metadata)
        type = BUNDLE_MATERIAL_TYPES.index(metadata.material_type.to_s.strip.downcase)
        order = metadata.material_order.to_i.positive? ? metadata.material_order.to_i : Float::INFINITY
        [[type, position, order, authored], material] if type
      end.sort_by(&:first).map { MaterialPresenter.new(it.last) }
  end

  # Every material the lesson's activities list, of any type, in activity
  # order (Teacher Bundle for Digital Access and Full Unit Content for
  # Download: the lesson folder, responses in #sample_responses_folder_name).
  #
  # @return [Array<MaterialPresenter>]
  def lesson_materials
    @lesson_materials ||= listed_materials.map { MaterialPresenter.new(it.first) }
  end

  # The lesson's sub-folder for its response materials (as PDFs) in the
  # Teacher Bundle for Digital Access and the Full Unit Content for Download:
  # "S2S_GK_01_Sample_Student_Responses" (unit id, grade, lesson number).
  def sample_responses_folder_name
    number = lesson_number.to_s.strip
    number = number.rjust(2, "0") if number.match?(/\A\d\z/)
    grade_label = ("G#{grade.to_s.strip.upcase}" if grade.present?)
    [unit_id.to_s.strip.upcase.presence, grade_label, number.presence, "Sample_Student_Responses"].compact.join("_")
  end

  # Aggregates activity-metadata material fields into the 5-row lesson
  # Materials summary table (spec "LCMS Core Lesson > Materials Table"). Each
  # row collects the entries of every activity — a comma, semicolon or line
  # break starts a new entry — keeps their authored bold/italics, drops
  # duplicates (compared by text), and renders them as a bulleted list with
  # [material: id] tokens resolved to italicized material titles (matching
  # how MaterialTag renders inline). A category with no materials in the
  # lesson renders "None", so the table always shows all five rows (including
  # a lesson with no activities, where every row is "None").
  #
  # @return [Hash{String => String}] heading => bulleted-list HTML
  #   (or "None" for an empty category).
  def materials_summary
    activities = Array.wrap(activity_metadata)

    rows = MATERIALS_ROWS.transform_values do |key|
      activities.flat_map { |a| material_entries(a, key) }.uniq { Nokogiri::HTML.fragment(it).text.squish.downcase }
    end

    # Single query for every [material: id] token across all five rows.
    known = DocTemplate::Tags::MaterialTokens.lookup(
      rows.values.flatten.flat_map { |v| DocTemplate::Tags::MaterialTokens.identifiers_in(v) }
    )

    rows.transform_values do |values|
      next "None" if values.empty?

      items = values.map { "<li>#{DocTemplate::Tags::MaterialTokens.resolve(it, known:)}</li>" }
      %(<ul class="c-lesson-materials__list">#{items.join}</ul>)
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
      keep_blank_lines(DocTemplate::Tags::MaterialTokens.resolve(base_metadata.lesson_prep&.lesson_prep_directions))
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

  # The Overview bullets in order — previous lesson, this lesson, next lesson
  # (#overview_past, #description, #overview_future) — without the ones that
  # carry no visible text. A blank Google Doc cell still arrives as markup
  # (e.g. `<p style="height:11pt"></p>`), which is not `blank?` and would
  # otherwise render as an empty bullet. An entry holding only an image counts
  # as content.
  def overview_items
    [overview_past, description, overview_future].select do |html|
      fragment = Nokogiri::HTML.fragment(html.to_s)
      fragment.text.strip.present? || fragment.at_css("img").present?
    end
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
  # Page numbers are NOT in this list, and are not produced by this app at all.
  # A Google Doc page number is an AutoText element rather than text, so
  # replaceText could only ever stamp one fixed number onto every page — and no
  # API can create one either (DocumentApp has no appendPageNumber; the Docs REST
  # API reads AutoText but cannot insert it). The page number therefore comes
  # from the Drive TEMPLATE's own footer, added by hand with Insert -> Page
  # numbers, and copyFooter carries it into each generated doc untouched.
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
      grade_abbr,
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

  # "G3" for a numbered grade; Kindergarten and Pre-K as "K" and "PK".
  def grade_abbr
    value = grade.to_s.strip.upcase
    return if value.blank?

    value.match?(/\A\d+\z/) ? "G#{value}" : value
  end

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
  # [material, activity position] for each material the activities list, in
  # activity order; a material listed by several activities appears once,
  # with the first.
  def listed_materials
    @listed_materials ||= activities_in_order.each_with_index.flat_map do |activity, position|
      activity_materials(activity).map { [it, position] }
    end.uniq { |material, _| material.id }
  end

  # Activities in lesson order (their parse index), authored order otherwise.
  def activities_in_order
    Array.wrap(activity_metadata).each_with_index.sort_by { |activity, i| [activity["idx"].to_i, i] }.map(&:first)
  end

  # The materials one activity lists in its Materials rows, as `[material: id]`
  # tokens or bare ids, plus the ids recorded at import (material_ids), in
  # authored order. Unknown ids are skipped.
  def activity_materials(activity)
    identifiers = MATERIALS_ROWS.values.flat_map do |key|
      split_list(activity_field(activity, key)).flat_map do |entry|
        tokens = DocTemplate::Tags::MaterialTokens.identifiers_in(entry)
        tokens.presence || [entry.squish.downcase]
      end
    end
    ids = Array(activity["material_ids"]).map(&:to_i)
    found = Material.where(identifier: identifiers).or(Material.where(id: ids)).to_a
    by_identifier = found.index_by(&:identifier)
    by_id = found.index_by(&:id)
    (identifiers.filter_map { by_identifier[it] } + ids.filter_map { by_id[it] }).uniq(&:id)
  end

  def activity_field(activity, key)
    value = activity[key]
    return value if value.present?

    legacy = LEGACY_MATERIALS_KEYS[key]
    legacy ? activity[legacy] : value
  end

  # One activity's entries for a Materials row, as HTML snippets: the
  # authored cell HTML ("<key>-html", kept by Tables::Activity so bold/italics
  # survive) split into entries, or — for lessons imported before that copy
  # existed — the plain-text cell, split and escaped. Falls back to the legacy
  # key the same way #activity_field does.
  def material_entries(activity, key)
    html = activity["#{key}-html"].presence
    html ||= activity["#{LEGACY_MATERIALS_KEYS[key]}-html"].presence if activity[key].blank? && LEGACY_MATERIALS_KEYS[key]
    return DocTemplate::HtmlList.split(html) if html

    split_list(activity_field(activity, key)).map { ERB::Util.html_escape(it) }
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

  # An authored blank line between groups ("Before teaching Class Session 1"
  # … "Before teaching Class Session 2") arrives as an empty <p>, which
  # collapses to nothing in the PDF and may be dropped by the Google Docs
  # import. A non-breaking space gives it one line of height in both.
  def keep_blank_lines(html)
    return html if html.blank?

    fragment = Nokogiri::HTML.fragment(html)
    fragment.css("p").each do |p|
      next if p.text.strip.present? || p.at_css("img")

      p.inner_html = "&nbsp;"
    end
    fragment.to_html
  end
end
