class AddStatusToTutrole < ActiveRecord::Migration
  def change
    add_column :tutroles, :status, :string
  end
end
