# frozen_string_literal: true

# PDF page geometry is no longer edited on the admin Settings page: it is tuned
# together with the PDF stylesheets, so the in-code Settings::DEFAULTS[:pdf] is
# the source of truth. Reads are DB override → code defaults
# (Settings.get(:pdf, include_defaults: true)), and SeedPdfSettings copied the
# whole defaults hash into the DB, which shadowed every later code change.
# Dropping the stored row puts the code defaults back in charge. A deliberate
# per-install override can still be set from the console (see Setting::Pdf).
#
# The removed values are not recoverable, so `down` is a no-op.
class RemoveStoredPdfGeometry < ActiveRecord::Migration[8.1]
  def up
    # Destroying through the model fires Setting#after_commit, which expires
    # the Settings cache for :pdf.
    Settings.unset(:pdf)
  end

  def down; end
end
