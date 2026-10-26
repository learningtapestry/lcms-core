# frozen_string_literal: true

# Rows of the URL spreadsheet that `[url: url_id]` tags resolve against
# (see LinksImportService and DocTemplate::Tags::UrlTag).
class CreateLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :links do |t|
      t.string :identifier, null: false
      t.text :url, null: false
      t.text :text
      t.timestamps
    end
    add_index :links, :identifier, unique: true
  end
end
