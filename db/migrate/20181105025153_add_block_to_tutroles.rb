class AddBlockToTutroles < ActiveRecord::Migration[5.0]
  def change
    add_column :tutroles, :block, :integer
    add_column :tutroles, :first, :integer
    add_column :tutroles, :next, :integer

    add_index:tutroles, :block
    add_index:tutroles, :first
    add_index:tutroles, :next
  end
end
