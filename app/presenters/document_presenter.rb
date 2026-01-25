# frozen_string_literal: true

class DocumentPresenter < ContentPresenter
  include Rails.application.routes.url_helpers

  delegate :cc_attribution, :grade, :lesson, :module, :subject, :teaser, :title, :unit, to: :base_metadata

  def content_for(context_type, options = {})
    render_content(context_type, options)
  end

  def description
    base_metadata.lesson_objective.presence || base_metadata.description
  end

  # Footer data for Google Apps Script post-processing.
  # Used in Google::ScriptService#parameters.
  #
  # @return [Array<Array<String>>] 2D array with placeholder/value pairs:
  #   [["{placeholder}"], [replacement_value]]
  def gdoc_footer
    [
      ["{attribution}"],
      [cc_attribution.presence || "Copyright attribution here"]
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
      [title]
    ]
  end

  def base_metadata
    @base_metadata ||= DocTemplate::Objects::Document.build_from(metadata)
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
    lesson_abbr = with_short_lesson ? "L#{lesson}" : "Lesson #{lesson}" \
      unless unit_level
    module_value = ela? ? send(:module) : unit
    [
      with_subject ? SUBJECTS[subject] || SUBJECT_DEFAULT : nil,
      grade.to_i.zero? ? grade : "G#{grade}",
      "M#{module_value.upcase}",
      lesson_abbr
    ].compact.join(join_with)
  end

  def short_title
    "Lesson #{lesson}"
  end

  def standards
    base_metadata.standard.presence || base_metadata.lesson_standard
  end
end
