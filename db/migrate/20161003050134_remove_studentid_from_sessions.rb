class RemoveStudentidFromSessions < ActiveRecord::Migration
  def change
    remove_column :sessions, :student_id, :integer
  end
end
