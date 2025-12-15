# frozen_string_literal: true

class MaterialPresenter < ContentPresenter
  attr_accessor :document

  delegate :name_date, :show_title, :subject, to: :base_metadata

  DEFAULT_TITLE = "Material"
  MATERIAL_TYPES = {
    rubric: "rubric",
    tool: "tool",
    reference_guide: "reference_guide"
  }.freeze

  def base_filename(with_version: true)
    name = base_metadata.identifier
    name = "#{document.short_breadcrumb(join_with: '_', with_short_lesson: true)}_#{name}"
    with_version ? "#{name}_v#{version.presence || 1}" : name
  end

  def cc_attribution
    base_metadata.cc_attribution.presence || document&.cc_attribution
  end

  def content_for(context_type, options = {})
    render_content(context_type, options)
  end

  def gdoc_folder
    "#{document.id}_v#{document.version}"
  end

  def gdoc_preview_title
    preview_links["gdoc"].present? ? "Preview Google Document" : "Generate Google Document"
  end

  def gdoc_url
    material_url("gdoc")
  end

  def header?
    config[:header]
  end

  def material_filename
    "materials/#{id}/#{base_filename}"
  end

  def orientation
    base_metadata.orientation.presence || super
  end

  def pdf_filename
    "#{document.id}/#{base_filename}"
  end

  def pdf_url
    material_url("url")
  end

  def pdf_preview_title
    preview_links["pdf"].present? ? "Preview PDF" : "Generate PDF"
  end

  def render_content(context_type, options = {})
    options[:parts_index] = document_parts_index
    DocumentRenderer::Part.call(layout_content(context_type), options)
  end

  def student_material?
    ::Material.where(id:).gdoc.where_metadata_any_of(materials_config_for(:student)).exists?
  end

  def subtitle
    config.dig(:subtitle).presence || DEFAULT_TITLE
  end

  def teacher_material?
    ::Material.where(id:).gdoc.where_metadata_any_of(materials_config_for(:teacher)).exists?
  end

  def title
    base_metadata.title.presence || config[:title].presence || DEFAULT_TITLE
  end

  def thumb_url
    material_url("thumb")
  end

  private

  def base_metadata
    @base_metadata ||= DocTemplate::Objects::Material.build_from(metadata)
  end

  def material_links
    @material_links ||= (document || @lesson).links["materials"]&.dig(id.to_s)
  end

  def material_url(key)
    material_links&.dig(key).to_s
  end
end
