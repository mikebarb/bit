class AddFirstToTutors < ActiveRecord::Migration
  def change
    add_column :tutors, :firstaid, :string
    add_column :tutors, :firstlesson, :string
  end
end
