# frozen_string_literal: true

# Migration that adds a demo tag to demonstrate plugin migrations
#
# This migration creates a tag that can be identified as created by the plugin.
class AddPluginDemoTag < ActiveRecord::Migration[8.1]
  DEMO_TAG_NAME = "plugin-demo-tag"

  def up
    # Use execute to avoid issues with model loading during migration
    execute <<-SQL.squish
      INSERT INTO tags (name, taggings_count)
      VALUES ('#{DEMO_TAG_NAME}', 0)
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    execute <<-SQL.squish
      DELETE FROM tags WHERE name = '#{DEMO_TAG_NAME}'
    SQL
  end
end
