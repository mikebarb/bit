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

ActiveRecord::Schema.define(version: 20180215070059) do

  create_table "googles", force: :cascade do |t|
    t.string   "user"
    t.string   "client_id"
    t.string   "access_token"
    t.string   "refresh_token"
    t.string   "scope"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "expiration_time_millis"
  end

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
  end

  add_index "roles", ["lesson_id", "student_id"], name: "index_roles_on_lesson_id_and_student_id", unique: true
  add_index "roles", ["lesson_id"], name: "index_roles_on_lesson_id"
  add_index "roles", ["student_id"], name: "index_roles_on_student_id"

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

  add_index "students", ["pname"], name: "index_students_on_pname", unique: true

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
  end

  add_index "tutors", ["pname"], name: "index_tutors_on_pname", unique: true

  create_table "tutroles", force: :cascade do |t|
    t.integer  "lesson_id"
    t.integer  "tutor_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "comment"
    t.string   "status"
  end

  add_index "tutroles", ["lesson_id", "tutor_id"], name: "index_tutroles_on_lesson_id_and_tutor_id", unique: true
  add_index "tutroles", ["lesson_id"], name: "index_tutroles_on_lesson_id"
  add_index "tutroles", ["tutor_id"], name: "index_tutroles_on_tutor_id"

end
