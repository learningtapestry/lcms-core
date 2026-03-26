# frozen_string_literal: true

class CreatePluginDemoTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.integer :taggings_count, default: 0
      t.index :name, unique: true
    end
  end
end
