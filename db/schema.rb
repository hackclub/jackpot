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

ActiveRecord::Schema[8.1].define(version: 2026_02_26_113000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "blazer_audits", force: :cascade do |t|
    t.datetime "created_at"
    t.string "data_source"
    t.bigint "query_id"
    t.text "statement"
    t.bigint "user_id"
    t.index ["query_id"], name: "index_blazer_audits_on_query_id"
    t.index ["user_id"], name: "index_blazer_audits_on_user_id"
  end

  create_table "blazer_checks", force: :cascade do |t|
    t.string "check_type"
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.text "emails"
    t.datetime "last_run_at"
    t.text "message"
    t.bigint "query_id"
    t.string "schedule"
    t.text "slack_channels"
    t.string "state"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_checks_on_creator_id"
    t.index ["query_id"], name: "index_blazer_checks_on_query_id"
  end

  create_table "blazer_dashboard_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dashboard_id"
    t.integer "position"
    t.bigint "query_id"
    t.datetime "updated_at", null: false
    t.index ["dashboard_id"], name: "index_blazer_dashboard_queries_on_dashboard_id"
    t.index ["query_id"], name: "index_blazer_dashboard_queries_on_query_id"
  end

  create_table "blazer_dashboards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_dashboards_on_creator_id"
  end

  create_table "blazer_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.string "data_source"
    t.text "description"
    t.string "name"
    t.text "statement"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_queries_on_creator_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "journal_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.decimal "hours_worked", precision: 5, scale: 2
    t.bigint "project_id"
    t.integer "project_index", null: false
    t.string "project_name", null: false
    t.datetime "time_done"
    t.string "tools_used", default: [], array: true
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "project_index"], name: "index_journal_entries_on_user_id_and_project_index"
  end

  create_table "projects", force: :cascade do |t|
    t.text "admin_feedback"
    t.decimal "approved_hours", precision: 10, scale: 2
    t.decimal "chips_earned", precision: 10, scale: 2
    t.string "code_url"
    t.datetime "created_at", null: false
    t.text "description"
    t.json "hackatime_projects", default: [], null: false
    t.string "hour_justification"
    t.string "name", null: false
    t.string "playable_url"
    t.integer "position", default: 0
    t.string "project_type"
    t.boolean "reviewed", default: false, null: false
    t.datetime "reviewed_at"
    t.boolean "shipped", default: false, null: false
    t.datetime "shipped_at"
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_projects_on_user_id_and_name"
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "rsvp_tables", force: :cascade do |t|
    t.string "airtable_id"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "ip"
    t.string "ref"
    t.date "synced_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
  end

  create_table "shop_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "logo_url"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_shop_categories_on_key", unique: true
    t.index ["name"], name: "index_shop_categories_on_name", unique: true
  end

  create_table "shop_grant_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "logo_url"
    t.string "name", null: false
    t.bigint "shop_category_id", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_category_id", "key"], name: "index_shop_grant_types_on_shop_category_id_and_key", unique: true
    t.index ["shop_category_id", "name"], name: "index_shop_grant_types_on_shop_category_id_and_name", unique: true
    t.index ["shop_category_id"], name: "index_shop_grant_types_on_shop_category_id"
  end

  create_table "shop_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "grant_type"
    t.string "image_url"
    t.string "item_link"
    t.integer "max_per_person"
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.bigint "shop_grant_type_id"
    t.datetime "updated_at", null: false
    t.index ["max_per_person"], name: "index_shop_items_on_max_per_person"
    t.index ["shop_grant_type_id"], name: "index_shop_items_on_shop_grant_type_id"
  end

  create_table "shop_orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "item_name", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "quantity", default: 1, null: false
    t.bigint "shop_item_id"
    t.string "slack_id"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.string "user_email"
    t.bigint "user_id", null: false
    t.index ["shop_item_id"], name: "index_shop_orders_on_shop_item_id"
    t.index ["user_id"], name: "index_shop_orders_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "access_token_ciphertext"
    t.string "airtable_id"
    t.decimal "chip_am", precision: 10, scale: 1, default: "0.0"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email"
    t.string "hack_club_id"
    t.datetime "last_sign_in_at"
    t.string "profile_photo_url"
    t.jsonb "projects", default: []
    t.string "provider"
    t.integer "role"
    t.string "slack_id"
    t.string "slack_username"
    t.date "synced_at"
    t.boolean "tutorial_completed", default: false, null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "journal_entries", "projects"
  add_foreign_key "journal_entries", "users"
  add_foreign_key "projects", "users"
  add_foreign_key "shop_grant_types", "shop_categories"
  add_foreign_key "shop_items", "shop_grant_types"
  add_foreign_key "shop_orders", "shop_items"
  add_foreign_key "shop_orders", "users"
end
