# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20180605080258) do

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
  end

  add_index "changes", ["rid"], name: "index_changes_on_rid", using: :btree
  add_index "changes", ["table"], name: "index_changes_on_table", using: :btree

  create_table "lessons", force: :cascade do |t|
    t.integer  "slot_id"
    t.text     "comments"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status"
  end

  create_table "roles", force: :cascade do |t|
    t.integer  "lesson_id"
    t.integer  "student_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "comment"
    t.string   "status"
    t.string   "kind"
  end

  add_index "roles", ["kind"], name: "index_roles_on_kind", using: :btree
  add_index "roles", ["lesson_id", "student_id"], name: "index_roles_on_lesson_id_and_student_id", unique: true, using: :btree
  add_index "roles", ["lesson_id"], name: "index_roles_on_lesson_id", using: :btree
  add_index "roles", ["status"], name: "index_roles_on_status", using: :btree
  add_index "roles", ["student_id"], name: "index_roles_on_student_id", using: :btree

  create_table "slots", force: :cascade do |t|
    t.datetime "timeslot"
    t.string   "location"
    t.text     "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
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
  end

  add_index "students", ["pname"], name: "index_students_on_pname", unique: true, using: :btree

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
  end

  add_index "tutors", ["pname"], name: "index_tutors_on_pname", unique: true, using: :btree

  create_table "tutroles", force: :cascade do |t|
    t.integer  "lesson_id"
    t.integer  "tutor_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "comment"
    t.string   "status"
    t.string   "kind"
  end

  add_index "tutroles", ["kind"], name: "index_tutroles_on_kind", using: :btree
  add_index "tutroles", ["lesson_id", "tutor_id"], name: "index_tutroles_on_lesson_id_and_tutor_id", unique: true, using: :btree
  add_index "tutroles", ["lesson_id"], name: "index_tutroles_on_lesson_id", using: :btree
  add_index "tutroles", ["status"], name: "index_tutroles_on_status", using: :btree
  add_index "tutroles", ["tutor_id"], name: "index_tutroles_on_tutor_id", using: :btree

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
  end

  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  add_index "users", ["unlock_token"], name: "index_users_on_unlock_token", unique: true, using: :btree

end
