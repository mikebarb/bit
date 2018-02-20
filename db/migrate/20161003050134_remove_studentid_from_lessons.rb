class RemoveStudentidFromLessons < ActiveRecord::Migration
  def change
    remove_column :lessons, :student_id, :integer
  end
end
