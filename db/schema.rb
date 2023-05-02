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

ActiveRecord::Schema.define(version: 2023_05_02_194109) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "coverage_checks", force: :cascade do |t|
    t.string "head_sha"
    t.jsonb "repo"
    t.text "lcov"
    t.jsonb "event_log"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "annotations"
    t.string "base_sha"
    t.string "state"
    t.jsonb "state_log"
    t.bigint "installation_id"
    t.jsonb "check_suite"
    t.index ["installation_id"], name: "index_coverage_checks_on_installation_id"
    t.index ["repo"], name: "index_coverage_checks_on_repo", opclass: :jsonb_path_ops, using: :gin
  end

  create_table "installations", force: :cascade do |t|
    t.bigint "installation_id"
    t.jsonb "metadata"
    t.jsonb "repos"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["installation_id"], name: "index_installations_on_installation_id", unique: true
  end

  create_table "nodes", force: :cascade do |t|
    t.bigint "coverage_check_id", null: false
    t.string "path", null: false
    t.string "node_type", null: false
    t.string "node_name", null: false
    t.integer "start_line", null: false
    t.integer "end_line", null: false
    t.decimal "coverage", precision: 5, scale: 4, null: false
    t.boolean "flagged", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["coverage_check_id"], name: "index_nodes_on_coverage_check_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "installation_id", null: false
    t.string "gumroad_id"
    t.string "license_key"
    t.string "state"
    t.datetime "end_date"
    t.jsonb "state_log"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["installation_id"], name: "index_subscriptions_on_installation_id"
  end

  create_table "user_installations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "installation_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["installation_id"], name: "index_user_installations_on_installation_id"
    t.index ["user_id", "installation_id"], name: "index_user_installations_on_user_id_and_installation_id", unique: true
    t.index ["user_id"], name: "index_user_installations_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.string "uid"
    t.string "token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "coverage_checks", "installations"
  add_foreign_key "subscriptions", "installations"
  add_foreign_key "user_installations", "installations"
  add_foreign_key "user_installations", "users"
end
