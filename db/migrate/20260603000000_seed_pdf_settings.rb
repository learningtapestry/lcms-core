# frozen_string_literal: true

# Materialises the PDF rendering settings into the `settings` table so they
# are visible and editable in the admin UI. The structure is seeded from the
# canonical defaults (Settings::DEFAULTS[:pdf]); operators edit the values
# from there. Guarded so re-runs never clobber existing (edited) values.
class SeedPdfSettings < ActiveRecord::Migration[8.1]
  def up
    return if Settings.get(:pdf).present?

    Settings.set(:pdf, Settings::DEFAULTS[:pdf].deep_stringify_keys)
  end

  def down
    Settings.unset(:pdf)
  end
end
