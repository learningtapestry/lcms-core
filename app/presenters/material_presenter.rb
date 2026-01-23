# frozen_string_literal: true

class MaterialPresenter < ContentPresenter
  delegate :grade, :name_date, :show_title, :subject, to: :base_metadata

  DEFAULT_TITLE = "Material"

  def base_filename
    base_metadata.identifier
  end

  def cc_attribution
    base_metadata.cc_attribution.to_s
  end

  def content_for(context_type, options = {})
    render_content(context_type, options)
  end

  def gdoc_preview_title
    preview_links["gdoc"].present? ? I18n.t("admin.common.preview_gdoc") : I18n.t("admin.common.generate_gdoc")
  end

  def header?
    config[:header]
  end

  def orientation
    base_metadata.orientation.presence || super
  end

  def pdf_filename
    "#{base_filename}.pdf"
  end

  def pdf_preview_title
    preview_links["pdf"].present? ? I18n.t("admin.common.preview_pdf") : I18n.t("admin.common.generate_pdf")
  end

  def render_content(context_type, options = {})
    options[:parts_index] = document_parts_index
    DocumentRenderer::Part.call(layout_content(context_type), options)
  end

  def subtitle
    config.dig(:subtitle).presence || DEFAULT_TITLE
  end

  def title
    base_metadata.title.presence || config[:title].presence || DEFAULT_TITLE
  end

  private

  def base_metadata
    @base_metadata ||= DocTemplate::Objects::Material.build_from(metadata)
  end
end
