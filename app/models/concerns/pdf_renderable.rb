# frozen_string_literal: true

#
# Per-record PDF renderer + accessibility selection, stored in the
# existing jsonb `metadata` column. No migration required.
#
# Read side: Exporters::Pdf::Base#renderer_name and #accessibility_level
# call `@document.pdf_renderer` and `@document.accessibility` (delegated
# from the presenter via SimpleDelegator). Both return nil when unset,
# and the exporter falls through to the registry default / `:none`.
#
# Write side: admin UI / console / migrations set values via the
# accessors. The accessibility writer validates against a closed set;
# the renderer writer accepts any symbol/string (registry validates at
# render time).
#
module PdfRenderable
  extend ActiveSupport::Concern

  ACCESSIBILITY_LEVELS = %w(none tagged pdf_ua).freeze

  def pdf_renderer
    metadata && metadata["pdf_renderer"].presence
  end

  def pdf_renderer=(value)
    write_pdf_metadata("pdf_renderer", value.presence&.to_s)
  end

  def accessibility
    metadata && metadata["accessibility"].presence
  end

  def accessibility=(value)
    str = value.presence&.to_s
    if str && !ACCESSIBILITY_LEVELS.include?(str)
      raise ArgumentError,
            "accessibility must be one of #{ACCESSIBILITY_LEVELS}, got #{value.inspect}"
    end
    write_pdf_metadata("accessibility", str)
  end

  private

  # Assigns a new hash to `metadata=` so ActiveRecord registers the change.
  def write_pdf_metadata(key, value)
    next_meta = (metadata || {}).dup
    if value.nil?
      next_meta.delete(key)
    else
      next_meta[key] = value
    end
    self.metadata = next_meta
  end
end
