# frozen_string_literal: true

class MaterialPresenter < ContentPresenter
  delegate :cc_attribution, :grade, :name_date, :show_title, :subject, to: :base_metadata

  DEFAULT_TITLE = "Material"

  def base_filename
    base_metadata.identifier
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

  def header?
    config[:header]
  end

  def orientation
    base_metadata.orientation.presence || super
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
    base_metadata.title.presence || config[:title].presence || DEFAULT_TITLE
  end

  private

  def base_metadata
    @base_metadata ||= DocTemplate::Objects::Material.build_from(metadata)
  end
end
