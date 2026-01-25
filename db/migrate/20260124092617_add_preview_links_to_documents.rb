class AddPreviewLinksToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :preview_links, :jsonb, default: {}
  end
end
