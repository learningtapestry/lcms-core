# frozen_string_literal: true

# Creates the `tags` table for the acts-as-taggable-on gem.
#
# This plugin owns the `tags` and `taggings` tables. Old tables from the main app
# are dropped first (they contain no data). The new tables use the default gem
# table names so that acts-as-taggable-on works without extra configuration.
#
# If another plugin needs tagging functionality, it should declare plugin_demo
# as a dependency rather than adding acts-as-taggable-on independently.
class CreateTags < ActiveRecord::Migration[8.1]
  def up
    # Drop old tables from the main app (order matters: taggings has FK to tags)
    drop_table :taggings, if_exists: true
    drop_table :tags, if_exists: true

    create_table :tags do |t|
      t.string :name, null: false
      t.integer :taggings_count, default: 0
      t.index :name, unique: true
    end
  end

  def down
    drop_table :tags
  end
end
