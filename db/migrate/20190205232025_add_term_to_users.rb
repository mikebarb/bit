class AddTermToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :termstart, :datetime
    add_column :users, :termweeks, :integer
  end
end
