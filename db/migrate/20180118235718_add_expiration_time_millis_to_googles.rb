class AddExpirationTimeMillisToGoogles < ActiveRecord::Migration
  def change
    add_column :googles, :expiration_time_millis, :integer
  end
end
