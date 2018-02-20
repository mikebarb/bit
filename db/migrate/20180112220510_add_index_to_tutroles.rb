class AddIndexToTutroles < ActiveRecord::Migration
  def change
    add_index:tutroles, [:lesson_id, :tutor_id], unique:true
  end
end
