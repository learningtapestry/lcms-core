# frozen_string_literal: true

# The `copyright_text` Documents setting was removed: the lesson footer's
# copyright line now comes from the unit-metadata `copyright` field. Drop any
# stored value so it doesn't linger in the `documents` row. Irreversible in
# substance (the value is gone), so `down` is a no-op.
class RemoveCopyrightTextSetting < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE settings SET value = value - 'copyright_text', updated_at = NOW()
      WHERE key = 'documents' AND value ? 'copyright_text'
    SQL
    # Raw SQL skips Setting's after_commit, and settings live in their own
    # cache store (Settings.cache), so expire it explicitly.
    Settings.expire_cache_for(:documents)
  end

  def down; end
end
