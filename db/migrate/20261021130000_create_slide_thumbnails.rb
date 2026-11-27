# frozen_string_literal: true

# Stored thumbnails of Google Slides pages for `[slide: id, n, size]` tags
# (see SlideThumbnailService). One row per slide of a deck revision, so a
# re-import reuses the image until the deck is edited.
class CreateSlideThumbnails < ActiveRecord::Migration[8.1]
  def change
    create_table :slide_thumbnails do |t|
      t.string :presentation_id, null: false
      t.string :revision_id, null: false
      t.integer :slide_number, null: false
      t.string :page_object_id, null: false
      t.string :file_url, null: false
      t.timestamps
    end
    add_index :slide_thumbnails, %i(presentation_id slide_number revision_id), unique: true,
                                                                                name: "index_slide_thumbnails_on_slide_revision"
  end
end
