class DropDocumentsMaterialsJoinTable < ActiveRecord::Migration[8.1]
  def up
    remove_index :documents_materials, %i[document_id material_id], if_exists: true
    remove_index :documents_materials, :material_id, if_exists: true
    drop_table :documents_materials
  end

  def down
    create_table :documents_materials, id: false do |t|
      t.integer :document_id
      t.integer :material_id
    end

    add_index :documents_materials, %i[document_id material_id], unique: true
    add_index :documents_materials, :material_id
  end
end
