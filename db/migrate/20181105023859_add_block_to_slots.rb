class AddBlockToSlots < ActiveRecord::Migration[5.0]
  def change
    add_column :slots, :first, :integer
    add_column :slots, :next, :integer

    add_index:slots, :first
    add_index:slots, :next
  end
end
