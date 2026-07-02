# frozen_string_literal: true

class MaterialPresenter < ContentPresenter
  delegate :attribution, :grade, :language, :material_id, :material_order,
           :material_title, :material_title_spanish, :material_type,
           :name_date, :subject, to: :base_metadata

  DEFAULT_TITLE = "Material"

  # External-asset representations (from the external-asset-representation
  # metadata table), in display order, mapping the stored key to a label.
  EXTERNAL_ASSETS = {
    "pdf" => "PDF",
    "doc" => "Document",
    "slides" => "Slides",
    "sheet" => "Sheet",
    "form" => "Form",
    "video" => "Video",
    "webpage" => "Webpage"
  }.freeze

  def base_filename
    base_metadata.material_id
  end

  # Populated external links for this material as {label:, url:} hashes, in
  # EXTERNAL_ASSETS order. Empty when the material has no external assets.
  def external_assets
    raw = metadata["external_assets"] || {}
    EXTERNAL_ASSETS.filter_map do |key, label|
      url = raw[key].to_s.strip
      { label:, url: } if url.present?
    end
  end

  def content_for(context_type, options = {})
    render_content(context_type, options)
  end

  # Footer data for Google Apps Script post-processing.
  # Used in Google::ScriptService#parameters.
  #
  # @return [Array<Array<String>>] 2D array with placeholder/value pairs:
  #   [["{placeholder}"], [replacement_value]]
  def gdoc_footer
    [
      ["{attribution}"],
      [attribution.presence || "Copyright attribution here"]
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

  def header?
    render_options.show_header
  end

  def pdf_filename
    "#{base_filename}.pdf"
  end

  def render_content(context_type, options = {})
    options[:parts_index] = document_parts_index
    DocumentRenderer::Part.call(layout_content(context_type), options)
  end

  def subtitle
    config.dig(:subtitle).presence || DEFAULT_TITLE
  end

  def title
    base_metadata.material_title
  end

  private

  def base_metadata
    @base_metadata ||= DocTemplate::Objects::Material.build_from(metadata)
  end

  def effective_orientation
    base_metadata.orientation.presence || super
  end
end
