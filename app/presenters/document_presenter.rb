# frozen_string_literal: true

class DocumentPresenter < ContentPresenter
  include Rails.application.routes.url_helpers

  delegate :cc_attribution, :description_future, :description_past, :estimated_time, :grade,
           :lesson_title, :lesson_number, :lesson_type, :section_number, :subject, :unit_id,
           :vocabulary, :teaser,
           to: :base_metadata

  MATERIALS_ROWS = {
    "Individual Student Materials" => "activity-materials-student",
    "Pair Materials" => "activity-materials-pair",
    "Small Group Materials" => "activity-materials-group",
    "Class Materials" => "activity-materials-class",
    "Teacher Materials" => "activity-metadata-teacher"
  }.freeze

  def brandmark_url
    raw = Setting.get(:documents, include_defaults: true)&.dig(:brandmark)
    return nil if raw.blank?

    # Inline as data URI so the image survives HTML→Gdoc import (and the
    # gdoc_pdf renderer, which routes PDF through Drive). Falls back
    # to the raw URL if the fetch fails — works for Grover/Chromium.
    AssetHelper.inline_data_uri(raw, cache: ViewHelper::ENABLE_BASE64_CACHING) || raw
  end

  def copyright_text
    Setting.get(:documents, include_defaults: true)&.dig(:copyright_text).presence
  end

  # Bold breadcrumb line used in the lesson footer.
  # @return [String, nil] e.g. "Grade 6/Course • Unit Title • Lesson 2"
  def footer_breadcrumb
    parts = [grade_label, unit_title, lesson_label].compact_blank
    parts.any? ? parts.join(" • ") : nil
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

  def grade_label
    return nil if grade.blank?

    "Grade #{grade}/Course"
  end

  def unit_title
    resource&.ancestors&.find(&:unit?)&.title.presence ||
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
