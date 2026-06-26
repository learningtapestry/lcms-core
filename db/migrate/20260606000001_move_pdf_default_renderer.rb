# frozen_string_literal: true

# The PDF renderer choice used to live inside the :pdf geometry setting as a
# top-level `default_renderer` key (when renderer + geometry shared one model).
# It now has its own :pdf_renderer setting, so move any stored value across and
# strip the stale key from :pdf — otherwise the geometry form renders it as a
# stray text field. Idempotent and safe to re-run.
class MovePdfDefaultRenderer < ActiveRecord::Migration[8.1]
  def up
    pdf = Settings.get(:pdf)
    return unless pdf.is_a?(Hash) && pdf.key?("default_renderer")

    renderer = pdf["default_renderer"]
    # Don't clobber an explicitly-configured :pdf_renderer; only seed it from the
    # old value when it has not been set yet.
    if Settings.get(:pdf_renderer).blank? && renderer.present?
      Settings.set(:pdf_renderer, "default_renderer" => renderer)
    end

    Settings.unset_within(:pdf, :default_renderer)
  end

  def down
    # One-directional: default_renderer lives in :pdf_renderer now.
  end
end
