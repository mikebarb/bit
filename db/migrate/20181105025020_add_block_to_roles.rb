class AddBlockToRoles < ActiveRecord::Migration[5.0]
  def change
    add_column :roles, :copied, :integer
    add_column :roles, :block, :integer
    add_column :roles, :first, :integer
    add_column :roles, :next, :integer

    add_index:roles, :block
    add_index:roles, :first
    add_index:roles, :next
  end
end
