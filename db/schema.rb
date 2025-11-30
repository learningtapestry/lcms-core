# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_28_065544) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "hstore"
  enable_extension "pg_catalog.plpgsql"

  create_table "access_codes", id: :serial, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_access_codes_on_code", unique: true
  end

  create_table "authors", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
  end

  create_table "copyright_attributions", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "disclaimer"
    t.integer "resource_id", null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
  end

  create_table "curriculums", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "default", default: false, null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
  end

  create_table "document_bundles", id: :serial, force: :cascade do |t|
    t.string "category", null: false
    t.string "content_type", default: "pdf", null: false
    t.datetime "created_at", null: false
    t.string "file"
    t.integer "resource_id"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["resource_id"], name: "index_document_bundles_on_resource_id"
  end

  create_table "document_parts", id: :serial, force: :cascade do |t|
    t.boolean "active"
    t.string "anchor"
    t.text "content"
    t.integer "context_type", default: 0
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.text "materials", default: [], null: false, array: true
    t.boolean "optional", default: false, null: false
    t.string "part_type"
    t.string "placeholder"
    t.integer "renderer_id"
    t.string "renderer_type"
    t.datetime "updated_at", null: false
    t.index ["anchor"], name: "index_document_parts_on_anchor"
    t.index ["context_type"], name: "index_document_parts_on_context_type"
    t.index ["placeholder"], name: "index_document_parts_on_placeholder"
    t.index ["renderer_type", "renderer_id"], name: "index_document_parts_on_renderer_type_and_renderer_id"
  end

  create_table "documents", id: :serial, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.jsonb "activity_metadata"
    t.jsonb "agenda_metadata"
    t.datetime "created_at", null: false
    t.text "css_styles"
    t.string "file_id"
    t.text "foundational_content"
    t.string "foundational_file_id"
    t.hstore "foundational_metadata"
    t.string "fs_name"
    t.string "last_author_email"
    t.string "last_author_name"
    t.datetime "last_modified_at"
    t.jsonb "links", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name"
    t.text "original_content"
    t.boolean "reimported", default: true, null: false
    t.datetime "reimported_at"
    t.integer "resource_id"
    t.jsonb "sections_metadata"
    t.jsonb "toc"
    t.datetime "updated_at", null: false
    t.string "version"
    t.index ["file_id"], name: "index_documents_on_file_id"
    t.index ["metadata"], name: "index_documents_on_metadata", using: :gin
    t.index ["resource_id"], name: "index_documents_on_resource_id"
  end

  create_table "documents_materials", id: false, force: :cascade do |t|
    t.integer "document_id"
    t.integer "material_id"
    t.index ["document_id", "material_id"], name: "index_documents_materials_on_document_id_and_material_id", unique: true
    t.index ["material_id"], name: "index_documents_materials_on_material_id"
  end

  create_table "download_categories", id: :serial, force: :cascade do |t|
    t.boolean "bundle", default: false, null: false
    t.text "description"
    t.text "long_description"
    t.integer "position"
    t.string "title", null: false
  end

  create_table "downloads", id: :serial, force: :cascade do |t|
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "description"
    t.string "filename"
    t.integer "filesize"
    t.boolean "main", default: false, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "lcms_engine_integrations_webhook_configurations", force: :cascade do |t|
    t.string "action", default: "post", null: false
    t.boolean "active", default: true
    t.jsonb "auth_credentials"
    t.string "auth_type"
    t.datetime "created_at", null: false
    t.string "endpoint_url", null: false
    t.string "event_name", null: false
    t.datetime "updated_at", null: false
    t.index ["event_name"], name: "index_webhook_configurations_on_event_name"
  end

  create_table "leadership_posts", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", limit: 4096
    t.string "first_name", null: false
    t.string "image_file"
    t.string "last_name", null: false
    t.integer "order"
    t.string "school"
    t.datetime "updated_at", null: false
    t.index ["order", "last_name"], name: "index_leadership_posts_on_order_and_last_name"
  end

  create_table "materials", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "css_styles"
    t.string "file_id", null: false
    t.string "identifier"
    t.string "last_author_email"
    t.string "last_author_name"
    t.datetime "last_modified_at"
    t.jsonb "links", default: {}
    t.jsonb "metadata", default: {}, null: false
    t.string "name"
    t.text "original_content"
    t.jsonb "preview_links", default: {}
    t.datetime "reimported_at"
    t.datetime "updated_at", null: false
    t.string "version"
    t.index ["file_id"], name: "index_materials_on_file_id"
    t.index ["identifier"], name: "index_materials_on_identifier"
    t.index ["metadata"], name: "index_materials_on_metadata", using: :gin
  end

  create_table "reading_assignment_authors", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.string "name", null: false
    t.datetime "updated_at"
    t.index ["name"], name: "index_reading_assignment_authors_on_name", unique: true
  end

  create_table "reading_assignment_texts", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.string "name", null: false
    t.integer "reading_assignment_author_id", null: false
    t.datetime "updated_at"
    t.index ["name"], name: "index_reading_assignment_texts_on_name"
    t.index ["reading_assignment_author_id"], name: "index_reading_assignment_texts_on_reading_assignment_author_id"
  end

  create_table "resource_additional_resources", id: :serial, force: :cascade do |t|
    t.integer "additional_resource_id", null: false
    t.datetime "created_at", null: false
    t.integer "position"
    t.integer "resource_id", null: false
    t.datetime "updated_at", null: false
    t.index ["additional_resource_id"], name: "index_resource_additional_resources_on_additional_resource_id"
    t.index ["resource_id", "additional_resource_id"], name: "index_resource_additional_resources", unique: true
  end

  create_table "resource_downloads", id: :serial, force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "download_category_id"
    t.integer "download_id"
    t.integer "resource_id"
    t.datetime "updated_at", null: false
    t.index ["download_category_id"], name: "index_resource_downloads_on_download_category_id"
    t.index ["download_id"], name: "index_resource_downloads_on_download_id"
    t.index ["resource_id"], name: "index_resource_downloads_on_resource_id"
  end

  create_table "resource_hierarchies", id: false, force: :cascade do |t|
    t.integer "ancestor_id", null: false
    t.integer "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id", "descendant_id", "generations"], name: "resource_anc_desc_idx", unique: true
    t.index ["descendant_id"], name: "resource_desc_idx"
  end

  create_table "resource_reading_assignments", id: :serial, force: :cascade do |t|
    t.integer "reading_assignment_text_id", null: false
    t.integer "resource_id", null: false
    t.index ["reading_assignment_text_id"], name: "idx_res_rea_asg_rea_asg_txt"
    t.index ["resource_id"], name: "index_resource_reading_assignments_on_resource_id"
  end

  create_table "resource_related_resources", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position"
    t.integer "related_resource_id"
    t.integer "resource_id"
    t.datetime "updated_at", null: false
    t.index ["related_resource_id"], name: "index_resource_related_resources_on_related_resource_id"
    t.index ["resource_id"], name: "index_resource_related_resources_on_resource_id"
  end

  create_table "resource_standards", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.integer "resource_id"
    t.integer "standard_id"
    t.datetime "updated_at"
    t.index ["resource_id"], name: "index_resource_standards_on_resource_id"
    t.index ["standard_id"], name: "index_resource_standards_on_standard_id"
  end

  create_table "resources", id: :serial, force: :cascade do |t|
    t.integer "author_id"
    t.datetime "created_at"
    t.integer "curriculum_id"
    t.string "curriculum_type"
    t.datetime "deleted_at"
    t.string "description"
    t.jsonb "download_categories_settings", default: {}, null: false
    t.boolean "ell_appropriate", default: false, null: false
    t.string "engageny_title"
    t.string "engageny_url"
    t.boolean "hidden", default: false
    t.string "hierarchical_position"
    t.string "image_file"
    t.datetime "indexed_at"
    t.integer "level_position"
    t.jsonb "links", default: {}
    t.jsonb "metadata", default: {}, null: false
    t.string "opr_description"
    t.integer "parent_id"
    t.integer "resource_type", default: 1, null: false
    t.string "short_title"
    t.string "slug"
    t.string "subtitle"
    t.string "teaser"
    t.integer "time_to_teach"
    t.string "title"
    t.boolean "tree", default: false, null: false
    t.datetime "updated_at"
    t.string "url"
    t.index ["author_id"], name: "index_resources_on_author_id"
    t.index ["curriculum_id"], name: "index_resources_on_curriculum_id"
    t.index ["deleted_at"], name: "index_resources_on_deleted_at"
    t.index ["indexed_at"], name: "index_resources_on_indexed_at"
    t.index ["metadata"], name: "index_resources_on_metadata", using: :gin
    t.index ["resource_type"], name: "index_resources_on_resource_type"
  end

  create_table "sessions", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.text "data"
    t.string "session_id", null: false
    t.datetime "updated_at"
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "social_thumbnails", id: :serial, force: :cascade do |t|
    t.string "image", null: false
    t.string "media", null: false
    t.integer "target_id", null: false
    t.string "target_type", null: false
    t.index ["target_type", "target_id"], name: "index_social_thumbnails_on_target_type_and_target_id"
  end

  create_table "staff_members", id: :serial, force: :cascade do |t|
    t.string "bio", limit: 4096
    t.datetime "created_at", null: false
    t.string "department"
    t.string "first_name"
    t.string "image_file"
    t.string "last_name"
    t.integer "order"
    t.string "position"
    t.integer "staff_type", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["first_name", "last_name"], name: "index_staff_members_on_first_name_and_last_name"
  end

  create_table "standard_links", id: :serial, force: :cascade do |t|
    t.string "description"
    t.string "link_type", null: false
    t.integer "standard_begin_id", null: false
    t.integer "standard_end_id", null: false
    t.index ["link_type"], name: "index_standard_links_on_link_type"
    t.index ["standard_begin_id"], name: "index_standard_links_on_standard_begin_id"
    t.index ["standard_end_id"], name: "index_standard_links_on_standard_end_id"
  end

  create_table "standards", id: :serial, force: :cascade do |t|
    t.text "alt_names", default: [], null: false, array: true
    t.string "course"
    t.datetime "created_at"
    t.string "description"
    t.string "domain"
    t.string "emphasis"
    t.text "grades", default: [], null: false, array: true
    t.string "label"
    t.string "name", null: false
    t.string "strand"
    t.string "subject"
    t.text "synonyms", default: [], array: true
    t.datetime "updated_at"
    t.index ["name"], name: "index_standards_on_name"
    t.index ["subject"], name: "index_standards_on_subject"
  end

  create_table "taggings", id: :serial, force: :cascade do |t|
    t.string "context", limit: 128
    t.datetime "created_at"
    t.integer "tag_id"
    t.integer "taggable_id"
    t.string "taggable_type"
    t.integer "tagger_id"
    t.string "tagger_type"
    t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true
    t.index ["taggable_id", "taggable_type", "context"], name: "index_taggings_on_taggable_id_and_taggable_type_and_context"
  end

  create_table "tags", id: :serial, force: :cascade do |t|
    t.string "name"
    t.integer "taggings_count", default: 0
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "access_code"
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.inet "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_sign_in_at"
    t.inet "last_sign_in_ip"
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.integer "sign_in_count", default: 0, null: false
    t.hstore "survey"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "copyright_attributions", "resources"
  add_foreign_key "document_bundles", "resources"
  add_foreign_key "documents_materials", "documents"
  add_foreign_key "documents_materials", "materials"
  add_foreign_key "reading_assignment_texts", "reading_assignment_authors"
  add_foreign_key "resource_additional_resources", "resources"
  add_foreign_key "resource_additional_resources", "resources", column: "additional_resource_id"
  add_foreign_key "resource_downloads", "download_categories", on_delete: :nullify
  add_foreign_key "resource_downloads", "downloads"
  add_foreign_key "resource_downloads", "resources"
  add_foreign_key "resource_reading_assignments", "reading_assignment_texts", name: "fk_res_rea_asg_rea_asg_txt"
  add_foreign_key "resource_reading_assignments", "resources"
  add_foreign_key "resource_related_resources", "resources"
  add_foreign_key "resource_related_resources", "resources", column: "related_resource_id"
  add_foreign_key "resource_standards", "resources"
  add_foreign_key "resource_standards", "standards"
  add_foreign_key "standard_links", "standards", column: "standard_begin_id"
  add_foreign_key "standard_links", "standards", column: "standard_end_id"
end
