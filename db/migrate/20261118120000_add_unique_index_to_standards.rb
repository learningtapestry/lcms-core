# frozen_string_literal: true

# A standard is identified by its code (`name`) within a subject, so the
# standards sheet can be synced in place: re-importing updates matching rows
# instead of re-creating them, and their resource links survive. Codes compare
# case-insensitively; a blank subject counts as one subject. Needs
# PostgreSQL 15+ (NULLS NOT DISTINCT).
class AddUniqueIndexToStandards < ActiveRecord::Migration[8.1]
  INDEX = "index_standards_on_subject_and_lower_name"

  def up
    # Store existing rows the way Standard now normalizes them, so rows that
    # differ only in case or spacing are caught below and later syncs match
    # them instead of adding a second copy.
    execute <<~SQL.squish
      UPDATE standards
      SET subject = NULLIF(lower(btrim(subject)), ''),
          name = regexp_replace(btrim(name), '\\s+', ' ', 'g')
    SQL

    duplicates = select_rows(<<~SQL.squish)
      SELECT subject, lower(name), count(*) FROM standards
      GROUP BY subject, lower(name) HAVING count(*) > 1 ORDER BY 1, 2
    SQL
    if duplicates.any?
      list = duplicates.first(20).map { |subject, code, count| "#{subject || '(no subject)'} #{code} x#{count}" }
      list << "and #{duplicates.size - 20} more" if duplicates.size > 20
      raise "Remove duplicate standards before migrating: #{list.join(', ')}"
    end

    add_index :standards, "subject, lower((name)::text)", unique: true, nulls_not_distinct: true, name: INDEX
  end

  def down
    remove_index :standards, name: INDEX
  end
end
