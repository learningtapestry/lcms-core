# frozen_string_literal: true

class CreateJobResults < ActiveRecord::Migration[8.1]
  def change
    create_table :job_results do |t|
      t.string :job_id, null: false
      t.string :parent_job_id
      t.string :job_class, null: false
      t.jsonb :result, default: {}
      t.timestamps
    end

    add_index :job_results, :job_id, unique: true
    add_index :job_results, :parent_job_id
    add_index :job_results, [:parent_job_id, :job_class]
  end
end
