class AddRosterToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :rosterstart, :datetime
    add_column :users, :rosterdays, :integer
    add_column :users, :rosterssurl, :string
  end
end
