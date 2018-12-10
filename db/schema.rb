# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20181202211428) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "changes", force: :cascade do |t|
    t.integer  "user"
    t.string   "table"
    t.integer  "rid"
    t.string   "field"
    t.text     "value"
    t.datetime "modified"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rid"], name: "index_changes_on_rid", using: :btree
    t.index ["table"], name: "index_changes_on_table", using: :btree
  end

  create_table "lessons", force: :cascade do |t|
    t.integer  "slot_id"
    t.text     "comments"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status"
    t.integer  "first"
    t.integer  "next"
    t.index ["first"], name: "index_lessons_on_first", using: :btree
    t.index ["next"], name: "index_lessons_on_next", using: :btree
  end

  create_table "roles", force: :cascade do |t|
    t.integer  "lesson_id"
    t.integer  "student_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "comment"
    t.string   "status"
    t.string   "kind"
    t.integer  "copied"
    t.integer  "block"
    t.integer  "first"
    t.integer  "next"
    t.index ["block"], name: "index_roles_on_block", using: :btree
    t.index ["first"], name: "index_roles_on_first", using: :btree
    t.index ["kind"], name: "index_roles_on_kind", using: :btree
    t.index ["lesson_id", "student_id"], name: "index_roles_on_lesson_id_and_student_id", unique: true, using: :btree
    t.index ["lesson_id"], name: "index_roles_on_lesson_id", using: :btree
    t.index ["next"], name: "index_roles_on_next", using: :btree
    t.index ["status"], name: "index_roles_on_status", using: :btree
    t.index ["student_id"], name: "index_roles_on_student_id", using: :btree
  end

  create_table "slots", force: :cascade do |t|
    t.datetime "timeslot"
    t.string   "location"
    t.text     "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "first"
    t.integer  "next"
    t.integer  "wpo"
    t.index ["first"], name: "index_slots_on_first", using: :btree
    t.index ["next"], name: "index_slots_on_next", using: :btree
  end

  create_table "students", force: :cascade do |t|
    t.string   "gname"
    t.string   "sname"
    t.string   "pname"
    t.string   "initials"
    t.string   "sex"
    t.text     "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status"
    t.string   "year"
    t.string   "study"
    t.string   "email"
    t.string   "phone"
    t.string   "invcode"
    t.string   "daycode"
    t.string   "preferences"
    t.index ["pname"], name: "index_students_on_pname", unique: true, using: :btree
  end

  create_table "tokenusers", force: :cascade do |t|
    t.text     "client_id"
    t.text     "token_json"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tutors", force: :cascade do |t|
    t.string   "gname"
    t.string   "sname"
    t.string   "pname"
    t.string   "initials"
    t.string   "sex"
    t.text     "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "subjects"
    t.string   "status"
    t.string   "email"
    t.string   "phone"
    t.string   "firstaid"
    t.string   "firstlesson"
    t.index ["pname"], name: "index_tutors_on_pname", unique: true, using: :btree
  end

  create_table "tutroles", force: :cascade do |t|
    t.integer  "lesson_id"
    t.integer  "tutor_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "comment"
    t.string   "status"
    t.string   "kind"
    t.integer  "block"
    t.integer  "first"
    t.integer  "next"
    t.index ["block"], name: "index_tutroles_on_block", using: :btree
    t.index ["first"], name: "index_tutroles_on_first", using: :btree
    t.index ["kind"], name: "index_tutroles_on_kind", using: :btree
    t.index ["lesson_id", "tutor_id"], name: "index_tutroles_on_lesson_id_and_tutor_id", unique: true, using: :btree
    t.index ["lesson_id"], name: "index_tutroles_on_lesson_id", using: :btree
    t.index ["next"], name: "index_tutroles_on_next", using: :btree
    t.index ["status"], name: "index_tutroles_on_status", using: :btree
    t.index ["tutor_id"], name: "index_tutroles_on_tutor_id", using: :btree
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.integer  "failed_attempts",        default: 0,  null: false
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "role"
    t.datetime "daystart"
    t.integer  "daydur"
    t.string   "ssurl"
    t.string   "sstab"
    t.integer  "history_back"
    t.integer  "history_forward"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
    t.index ["email"], name: "index_users_on_email", unique: true, using: :btree
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true, using: :btree
  end

end
