class CreateLessons < ActiveRecord::Migration
  def change
    create_table :lessons do |t|
      t.integer :student_id
      t.integer :tutor_id
      t.integer :slot_id
      t.text :comments

      t.timestamps
    end
  end
end
