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

ActiveRecord::Schema[7.2].define(version: 2024_11_20_104055) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "menus", force: :cascade do |t|
    t.bigint "stylist_id", null: false
    t.string "name"
    t.integer "price"
    t.integer "duration"
    t.text "description"
    t.string "category", default: [], array: true
    t.integer "sort_order"
    t.boolean "is_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stylist_id"], name: "index_menus_on_stylist_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "family_name"
    t.string "given_name"
    t.string "family_name_kana"
    t.string "given_name_kana"
    t.string "gender"
    t.date "date_of_birth"
    t.integer "role"
    t.string "provider"
    t.string "uid"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "menus", "users", column: "stylist_id"
end
