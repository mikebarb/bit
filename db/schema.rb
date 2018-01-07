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

ActiveRecord::Schema.define(version: 20180101073905) do

  create_table "roles", force: true do |t|
    t.integer  "session_id"
    t.integer  "student_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "roles", ["session_id", "student_id"], name: "index_roles_on_session_id_and_student_id", unique: true
  add_index "roles", ["session_id"], name: "index_roles_on_session_id"
  add_index "roles", ["student_id"], name: "index_roles_on_student_id"

  create_table "sessions", force: true do |t|
    t.integer  "slot_id"
    t.text     "comments"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "slots", force: true do |t|
    t.datetime "timeslot"
    t.string   "location"
    t.text     "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "students", force: true do |t|
    t.string   "gname"
    t.string   "sname"
    t.string   "pname"
    t.string   "initials"
    t.string   "sex"
    t.text     "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tutors", force: true do |t|
    t.string   "gname"
    t.string   "sname"
    t.string   "pname"
    t.string   "initials"
    t.string   "sex"
    t.text     "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tutroles", force: true do |t|
    t.integer  "session_id"
    t.integer  "tutor_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "tutroles", ["session_id"], name: "index_tutroles_on_session_id"
  add_index "tutroles", ["tutor_id"], name: "index_tutroles_on_tutor_id"

end
