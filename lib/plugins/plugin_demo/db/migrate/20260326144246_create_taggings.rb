# frozen_string_literal: true

# Creates the `taggings` table for the acts-as-taggable-on gem.
#
# This join table links tags to any taggable model (polymorphic).
# It is owned by the plugin_demo plugin together with the `tags` table.
class CreateTaggings < ActiveRecord::Migration[8.1]
  def change
    create_table :taggings do |t|
      t.references :tag, null: false, foreign_key: true
      t.references :taggable, polymorphic: true, null: false
      t.references :tagger, polymorphic: true
      t.string :context, limit: 128
      t.datetime :created_at

      t.index [:tag_id, :taggable_id, :taggable_type, :context, :tagger_id, :tagger_type],
              name: "taggings_idx", unique: true
    end
  end
end
