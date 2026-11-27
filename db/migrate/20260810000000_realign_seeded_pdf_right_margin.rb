# frozen_string_literal: true

# `SeedPdfSettings` (20260603000000) persisted the whole `Settings::DEFAULTS[:pdf]`
# hash into the `settings` table, and `Settings.merge_with_defaults` lets a stored
# value win over the shipped default. So lowering the default right margin from
# 1in to 0.5in — which the lesson banner and materials table widths are tuned for —
# has no effect on any environment seeded before that change: the stored 1in keeps
# shadowing it, and those PDFs render differently from a fresh install.
#
# Only the exact old shipped value is rewritten, so an operator who deliberately
# chose a different margin (or already runs 0.5in) is left alone. Idempotent.
class RealignSeededPdfRightMargin < ActiveRecord::Migration[8.1]
  OLD_DEFAULT = "1in"
  NEW_DEFAULT = "0.5in"

  def up
    migrate_right_margin(from: OLD_DEFAULT, to: NEW_DEFAULT)
  end

  def down
    migrate_right_margin(from: NEW_DEFAULT, to: OLD_DEFAULT)
  end

  private

  def migrate_right_margin(from:, to:)
    pdf = Settings.get(:pdf)
    return unless pdf.is_a?(Hash)
    return unless pdf.dig("default", "margin", "right") == from

    updated = pdf.deep_dup
    updated["default"]["margin"]["right"] = to
    Settings.set(:pdf, updated)
  end
end
