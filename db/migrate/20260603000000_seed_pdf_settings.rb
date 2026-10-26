# frozen_string_literal: true

# Materialises the PDF rendering settings into the `settings` table so they
# are visible and editable in the admin UI. The structure is seeded from the
# canonical defaults (Settings::DEFAULTS[:pdf]); operators edit the values
# from there. Guarded so re-runs never clobber existing (edited) values.
#
# This migration runs BEFORE `CreateSolidCacheEntries` (20260605000000), so it
# must not touch the Settings cache: both `Settings.get` (a `cache.fetch`) and
# `Settings.set` (via `Setting`'s `after_commit` cache invalidation) read/write
# the Solid Cache table, which does not exist yet at this point. Operating on
# the `settings` table directly through a callback-free local model keeps the
# seed independent of the cache backend.
class SeedPdfSettings < ActiveRecord::Migration[8.1]
  class MigrationSetting < ActiveRecord::Base
    self.table_name = "settings"
  end

  def up
    return if MigrationSetting.exists?(key: "pdf")

    MigrationSetting.create!(key: "pdf", value: Settings::DEFAULTS[:pdf].deep_stringify_keys)
  end

  def down
    MigrationSetting.where(key: "pdf").delete_all
  end
end
