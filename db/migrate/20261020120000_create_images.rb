# frozen_string_literal: true

# Rows of the image spreadsheet that `[image: id, size]` tags resolve against
# (see ImagesImportService and DocTemplate::Tags::ImageTag).
class CreateImages < ActiveRecord::Migration[8.1]
  def change
    create_table :images do |t|
      t.string :identifier, null: false
      t.string :file_url, null: false
      t.text :caption
      t.text :credit
      t.text :alt_text
      t.timestamps
    end
    add_index :images, :identifier, unique: true
  end
end
