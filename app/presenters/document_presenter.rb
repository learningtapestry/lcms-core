# frozen_string_literal: true

class DocumentPresenter < ContentPresenter
  include Rails.application.routes.url_helpers

  delegate :cc_attribution, :grade,
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

  def copyright_text
    Settings.get(:documents, include_defaults: true)&.dig(:copyright_text).presence
  end

  # Footer line 1: boilerplate copyright/company text (Settings) with the unit
  # version appended — e.g. "© Company Name, v1.0".
  def footer_copyright
    [copyright_text.presence, unit_version.presence].compact.join(", ").presence
  end

  # Footer line 2: the course name, from unit-metadata.
  def footer_course
    unit_metadata&.course.presence
  end

  # Footer line 3 (left cell): "Unit Title • Lesson N".
  def footer_unit_lesson
    [unit_title, lesson_label].compact_blank.join(" • ").presence
  end

  # Aggregates activity-metadata material fields into the 5-row lesson
  # Materials summary table. Each row collects values across all
  # activities, dedupes, joins, and resolves any [material: id] tokens
  # to italicized identifier links (matching how MaterialTag renders
  # inline). Empty rows render as "None".
  #
  # @return [Hash{String => String}] heading => joined materials HTML.
  #   Returns {} when the document has no activity metadata so the view
  #   can skip the Materials block entirely.
  def materials_summary
    activities = Array.wrap(activity_metadata)
    return {} if activities.empty?

    MATERIALS_ROWS.transform_values do |key|
      values = activities.flat_map { |a| split_list(a[key]) }.uniq.compact_blank
      next "None" if values.empty?

      values.map { |v| resolve_material_tokens(v) }.join(", ")
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
  # Blank when the lesson defines no preparation directions.
  def lesson_prep_directions
    base_metadata.lesson_prep&.lesson_prep_directions
  end

  # Overview bullet "In the previous lesson, we…" — the preceding lesson's
  # past-tense self-description. Per the lesson-metadata spec, each lesson's
  # `description-past` is authored to be shown in the FOLLOWING lesson, so it
  # is read from the previous lesson in the same unit. Nil when this is the
  # first lesson of the unit (no predecessor).
  def overview_past
    neighbor_lesson(:previous)&.description_past.presence
  end

  # Overview bullet "In the next lesson, we will…" — the following lesson's
  # future-tense self-description. Each lesson's `description-future` is
  # authored to be shown in the PRECEDING lesson, so it is read from the next
  # lesson in the same unit. Nil when this is the last lesson of the unit.
  def overview_future
    neighbor_lesson(:next)&.description_future.presence
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
  # NOTE: kept at the original 2-row shape. The R2 footer design (copyright
  # line + breadcrumb) is fully implemented in the PDF footer. To land it in
  # generated Gdocs we need to (a) update the Apps Script template doc in
  # Drive to use new placeholders AND (b) extend this array. Doing only (b)
  # makes the Apps Script post-processing hang on unfamiliar args.
  #
  # @return [Array<Array<String>>] 2D array with placeholder/value pairs:
  #   [["{placeholder}"], [replacement_value]]
  def gdoc_footer
    [
      ["{attribution}"],
      [
        [copyright_text.presence, cc_attribution.presence]
          .compact
          .join(" — ")
          .presence || "Copyright attribution here"
      ]
    ]
  end

  # Header data for Google Apps Script post-processing.
  # Used in Google::ScriptService#parameters.
  #
  # @return [Array<Array<String>>] 2D array with placeholder/value pairs:
  #   [["{placeholder}"], [replacement_value]]
  def gdoc_header
    [
      ["{title}"],
      [lesson_title]
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

  # Builds the adjacent lesson (:previous / :next) within the SAME unit as a
  # DocTemplate::Objects::Lesson, or nil at a unit boundary, when the document
  # has no resource, or when the neighbor has no active document.
  def neighbor_lesson(direction)
    return nil unless resource&.lesson?

    sibling = resource.public_send(direction)
    return nil unless sibling&.lesson? && same_unit?(sibling)

    doc = sibling.document
    return nil unless doc

    DocTemplate::Objects::Lesson.build_from(doc.metadata)
  end

  # True when `other` shares this lesson's unit ancestor.
  def same_unit?(other)
    unit_resource.present? && other.ancestors.include?(unit_resource)
  end

  # The unit-level Resource ancestor of this lesson (populated by
  # UnitBuildService), or nil when the document has no unit ancestor.
  def unit_resource
    return @unit_resource if defined?(@unit_resource)

    @unit_resource = resource&.ancestors&.find(&:unit?)
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

  def unit_title
    unit_metadata&.unit_title.presence ||
      unit_resource&.title.presence ||
      (unit_id.present? ? "Unit #{unit_id.to_s.upcase}" : nil)
  end

  def lesson_label
    lesson_number.to_i.positive? ? "Lesson #{lesson_number}" : nil
  end

  def split_list(value)
    return [] if value.blank?

    value.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  # Replaces `[material: id]` tokens in raw activity-metadata text with the
  # italicized identifier markup that MaterialTag emits inline. Plain text
  # is passed through unchanged.
  MATERIAL_TOKEN_RE = /\[material:\s*([^\]]+)\]/i

  def resolve_material_tokens(text)
    text.to_s.gsub(MATERIAL_TOKEN_RE) do
      identifier = ::Regexp.last_match(1).to_s.strip
      next identifier if identifier.blank?

      if ::Material.exists?(identifier: identifier.downcase)
        %(<a class="o-ld-material">#{identifier}</a>)
      else
        identifier
      end
    end
  end
end
