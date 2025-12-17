# frozen_string_literal: true

class DocumentPresenter < ContentPresenter
  include Rails.application.routes.url_helpers

  delegate :cc_attribution, :grade, :lesson, :module, :subject, :teaser, :title, :unit, to: :base_metadata

  def content_for(context_type, options = {})
    with_excludes = (options[:excludes] || []).any?
    content = render_content(context_type, options)
    content = update_activity_timing(content) if with_excludes
    content
  end

  def description
    base_metadata.lesson_objective.presence || base_metadata.description
  end

  def doc_type
    "lesson"
  end

  def base_metadata
    @base_metadata ||= DocTemplate::Objects::Document.build_from(metadata)
  end

  def pdf_filename
    name = short_breadcrumb(join_with: "_", with_short_lesson: true)
    name += PDF_SUBTITLES[content_type.to_sym]
    "#{name}_v#{version.presence || 1}#{ContentPresenter::PDF_EXT}"
  end

  #
  # Makes sure that time of group is equal to sum of timings of child activities
  #
  def update_activity_timing(content)
    html = Nokogiri::HTML.fragment content
    html.css(".o-ld-group").each do |group|
      group_time = group.css(".o-ld-title__time--h3").inject(0) { |time, section| time + section.text.to_i }
      group.at_css(".o-ld-title__time--h2").content = group_time.zero? ? "\u2014" : "#{group_time} mins"
    end
    html.to_html
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
      with_subject ? SUBJECT_FULL[subject] || subject : nil,
      grade.to_i.zero? ? grade : "G#{grade}",
      "M#{module_value.upcase}",
      topic.present? ? "#{TOPIC_SHORT[subject]}#{topic.try(:upcase)}" : nil,
      lesson_abbr
    ].compact.join(join_with)
  end

  def short_title
    "Lesson #{lesson}"
  end

  def standards
    base_metadata.standard.presence || base_metadata.lesson_standard
  end

  def student_materials
    materials.gdoc.where_metadata_any_of(materials_config_for(:student))
  end

  def student_materials_props
    DocumentMaterialSerializer.new(self, student_materials)
  end

  def teacher_materials
    materials.gdoc.where_metadata_any_of(materials_config_for(:teacher))
  end

  def teacher_materials_props
    DocumentMaterialSerializer.new(self, teacher_materials)
  end

  def topic
    ela? ? base_metadata.unit : base_metadata.topic
  end

  def unit
    @unit ||= resource&.parent
  end
end
