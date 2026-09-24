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

ActiveRecord::Schema[8.1].define(version: 2026_09_24_112008) do
  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "name_normalized", null: false
    t.datetime "updated_at", null: false
    t.index ["name_normalized"], name: "index_categories_on_name_normalized", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.string "brand", null: false
    t.string "brand_normalized", null: false
    t.integer "category_id", null: false
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.text "description"
    t.integer "lock_version", default: 0, null: false
    t.datetime "locked_at"
    t.string "name", null: false
    t.string "name_normalized", null: false
    t.integer "ratings_count", default: 0, null: false
    t.integer "ratings_sum", default: 0, null: false
    t.integer "retail_chain_id", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_normalized"], name: "index_products_on_brand_normalized"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["created_by_id"], name: "index_products_on_created_by_id"
    t.index ["name_normalized", "brand_normalized", "retail_chain_id"], name: "index_products_on_normalized_identity", unique: true
    t.index ["name_normalized"], name: "index_products_on_name_normalized"
    t.index ["retail_chain_id"], name: "index_products_on_retail_chain_id"
  end

  create_table "ratings", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.integer "product_id", null: false
    t.integer "stars", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["product_id"], name: "index_ratings_on_product_id"
    t.index ["user_id", "product_id"], name: "index_ratings_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_ratings_on_user_id"
  end

  create_table "reports", force: :cascade do |t|
    t.datetime "claimed_at"
    t.datetime "created_at", null: false
    t.datetime "decided_at"
    t.integer "moderator_id"
    t.integer "rating_id", null: false
    t.integer "reason", null: false
    t.integer "reporter_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["moderator_id"], name: "index_reports_on_moderator_id"
    t.index ["rating_id", "reporter_id"], name: "index_reports_on_rating_id_and_reporter_id", unique: true
    t.index ["rating_id"], name: "index_reports_on_rating_id"
    t.index ["reporter_id"], name: "index_reports_on_reporter_id"
  end

  create_table "retail_chains", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "name_normalized", null: false
    t.datetime "updated_at", null: false
    t.index ["name_normalized"], name: "index_retail_chains_on_name_normalized", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "locked_at"
    t.string "name", default: "", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "whodunnit"
    t.index ["created_at"], name: "index_versions_on_created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "products", "categories"
  add_foreign_key "products", "retail_chains"
  add_foreign_key "products", "users", column: "created_by_id"
  add_foreign_key "ratings", "products"
  add_foreign_key "ratings", "users"
  add_foreign_key "reports", "ratings"
  add_foreign_key "reports", "users", column: "moderator_id"
  add_foreign_key "reports", "users", column: "reporter_id"
  add_foreign_key "sessions", "users"
end
