class AddKindToRoles < ActiveRecord::Migration
  def change
    add_column :roles, :kind, :string
    add_index :roles, :kind
    add_index :roles, :status
  end
end
