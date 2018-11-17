class AddBlockToLessons < ActiveRecord::Migration[5.0]
  def change
    add_column :lessons, :first, :integer
    add_column :lessons, :next, :integer

    add_index:lessons, :first
    add_index:lessons, :next
  end
end
