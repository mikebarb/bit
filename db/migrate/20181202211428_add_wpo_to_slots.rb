class AddWpoToSlots < ActiveRecord::Migration[5.0]
  def change
    add_column :slots, :wpo, :integer
  end
end
