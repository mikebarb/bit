class AddRoleToUsers < ActiveRecord::Migration
  def change
    add_column :users, :role, :string
    add_column :users, :daystart, :datetime
    add_column :users, :daydur, :integer
    add_column :users, :ssurl, :string
    add_column :users, :sstab, :string
  end
end
