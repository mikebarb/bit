class AddIndexToTutroles < ActiveRecord::Migration
  def change
    add_index:tutroles, [:session_id, :tutor_id], unique:true
  end
end
