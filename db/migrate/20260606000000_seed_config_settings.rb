# frozen_string_literal: true

# Materialises the config settings migrated from YAML (doc_template,
# admin_view_links) into the `settings` table so they are visible and editable
# in the admin UI. Seeded from the canonical defaults; guarded so re-runs
# never clobber existing (edited) values.
class SeedConfigSettings < ActiveRecord::Migration[8.1]
  KEYS = %i(doc_template admin_view_links).freeze

  def up
    KEYS.each do |key|
      next if Settings.get(key).present?

      Settings.set(key, Settings::DEFAULTS[key].deep_stringify_keys)
    end
  end

  def down
    KEYS.each { |key| Settings.unset(key) }
  end
end
