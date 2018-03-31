class AddHistoryToUsers < ActiveRecord::Migration
  def change
    add_column :users, :history_back, :integer
    add_column :users, :history_forward, :integer
  end
end
