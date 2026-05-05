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

ActiveRecord::Schema[7.2].define(version: 2024_01_01_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "users", force: :cascade do |t|
    t.string "auth0_sub", null: false
    t.string "email", null: false
    t.string "role", default: "viewer", null: false
    t.integer "query_limit_days", default: 30, null: false
    t.boolean "active", default: true, null: false
    t.bigint "invited_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "query_limit_banner_dismissed", default: false, null: false
    t.index ["active"], name: "index_users_on_active"
    t.index ["auth0_sub"], name: "index_users_on_auth0_sub", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "users", "users", column: "invited_by_id"
end
