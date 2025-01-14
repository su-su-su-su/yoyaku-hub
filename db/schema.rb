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

ActiveRecord::Schema[7.2].define(version: 2025_01_11_143057) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "holidays", force: :cascade do |t|
    t.bigint "stylist_id", null: false
    t.date "target_date"
    t.integer "day_of_week"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_holiday", default: false, null: false
    t.index ["stylist_id", "target_date"], name: "index_holidays_on_stylist_id_and_target_date", unique: true
    t.index ["stylist_id"], name: "index_holidays_on_stylist_id"
    t.index ["target_date"], name: "index_holidays_on_target_date"
  end

  create_table "menus", force: :cascade do |t|
    t.bigint "stylist_id", null: false
    t.string "name", null: false
    t.integer "price", null: false
    t.integer "duration", null: false
    t.text "description"
    t.string "category", default: [], array: true
    t.integer "sort_order"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stylist_id", "name"], name: "index_menus_on_stylist_id_and_name", unique: true
    t.index ["stylist_id"], name: "index_menus_on_stylist_id"
  end

  create_table "reservation_limits", force: :cascade do |t|
    t.bigint "stylist_id", null: false
    t.date "target_date"
    t.integer "max_reservations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "time_slot"
    t.index ["stylist_id"], name: "index_reservation_limits_on_stylist_id"
    t.index ["target_date"], name: "index_reservation_limits_on_target_date"
  end

  create_table "reservation_menu_selections", force: :cascade do |t|
    t.bigint "menu_id", null: false
    t.bigint "reservation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["menu_id", "reservation_id"], name: "idx_on_menu_id_reservation_id_cff1c01803", unique: true
    t.index ["menu_id"], name: "index_reservation_menu_selections_on_menu_id"
    t.index ["reservation_id"], name: "index_reservation_menu_selections_on_reservation_id"
  end

  create_table "reservations", force: :cascade do |t|
    t.bigint "stylist_id", null: false
    t.bigint "customer_id", null: false
    t.datetime "start_at"
    t.datetime "end_at"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_reservations_on_customer_id"
    t.index ["end_at"], name: "index_reservations_on_end_at"
    t.index ["start_at"], name: "index_reservations_on_start_at"
    t.index ["stylist_id"], name: "index_reservations_on_stylist_id"
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

  create_table "working_hours", force: :cascade do |t|
    t.bigint "stylist_id", null: false
    t.date "target_date"
    t.time "start_time"
    t.time "end_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "day_of_week"
    t.index ["stylist_id", "target_date"], name: "index_working_hours_on_stylist_id_and_target_date", unique: true
    t.index ["stylist_id"], name: "index_working_hours_on_stylist_id"
    t.index ["target_date"], name: "index_working_hours_on_target_date"
  end

  add_foreign_key "holidays", "users", column: "stylist_id"
  add_foreign_key "menus", "users", column: "stylist_id"
  add_foreign_key "reservation_limits", "users", column: "stylist_id"
  add_foreign_key "reservation_menu_selections", "menus"
  add_foreign_key "reservation_menu_selections", "reservations"
  add_foreign_key "reservations", "users", column: "customer_id"
  add_foreign_key "reservations", "users", column: "stylist_id"
  add_foreign_key "working_hours", "users", column: "stylist_id"
end
