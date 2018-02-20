class AddIndexToRoles < ActiveRecord::Migration
  def change
    add_index:roles, [:lesson_id, :student_id], unique:true
  end
end
