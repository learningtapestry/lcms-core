# frozen_string_literal: true

class DocumentPresenter < ContentPresenter
  include Rails.application.routes.url_helpers

  PDF_SUBTITLES = { full: "", sm: "_student_materials", tm: "_teacher_materials" }.freeze
  SUBJECT_FULL  = { "ela" => "ELA", "math" => "Math" }.freeze
  TOPIC_FULL    = { "ela" => "Unit", "math" => "Topic" }.freeze
  TOPIC_SHORT   = { "ela" => "U", "math" => "T" }.freeze

  def cc_attribution
    metadata.cc_attribution
  end

  def color_code
    "#{subject}-base"
  end

  def color_code_grade
    "#{subject}-#{grade}"
  end

  def content_for(context_type, options = {})
    with_excludes = (options[:excludes] || []).any?
    content = render_content(context_type, options)
    content = update_activity_timing(content) if with_excludes
    content = remove_optional_break(content) if ela? && with_excludes
    content
  end

  def description
    metadata.lesson_objective.presence || metadata.description
  end

  def doc_type
    "lesson"
  end

  def grade
    metadata.grade[/\d+/] || metadata.grade
  end

  def remove_optional_break(content)
    html = Nokogiri::HTML.fragment content
    html.at_css(".o-ld-optbreak-wrapper")&.remove
    html.to_html
  end

  def metadata
    @ld_metadata ||= DocTemplate::Objects::Document.build_from(metadata)
  end

  def ld_module
    ela? ? metadata.module : metadata.unit
  end

  def lesson
    metadata.lesson
  end

  def ll_strand?
    metadata.module =~ /strand/i
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
    [
      with_subject ? SUBJECT_FULL[subject] || subject : nil,
      grade.to_i.zero? ? grade : "G#{grade}",
      ll_strand? ? "LL" : "M#{ld_module.try(:upcase)}",
      topic.present? ? "#{TOPIC_SHORT[subject]}#{topic.try(:upcase)}" : nil,
      lesson_abbr
    ].compact.join(join_with)
  end

  def short_title
    "Lesson #{lesson}"
  end

  def standards
    metadata.standard.presence || metadata.lesson_standard
  end

  def student_materials
    materials.gdoc.where_metadata_any_of(materials_config_for(:student))
  end

  def student_materials_props
    DocumentMaterialSerializer.new(self, student_materials)
  end

  def subject
    metadata&.subject
  end

  def subject_to_str
    SUBJECT_FULL[subject] || subject
  end

  def title
    metadata&.title
  end

  def teacher_materials
    materials.gdoc.where_metadata_any_of(materials_config_for(:teacher))
  end

  def teacher_materials_props
    DocumentMaterialSerializer.new(self, teacher_materials)
  end

  def teaser
    metadata.teaser
  end

  def topic
    ela? ? metadata.unit : metadata.topic
  end

  def unit
    @unit ||= resource&.parent
  end
end
