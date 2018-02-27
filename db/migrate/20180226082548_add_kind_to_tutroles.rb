class AddKindToTutroles < ActiveRecord::Migration
  def change
    add_column :tutroles, :kind, :string
    add_index :tutroles, :kind
    add_index :tutroles, :status
  end
end
