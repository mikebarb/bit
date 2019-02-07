class AddBflToTutors < ActiveRecord::Migration[5.0]
  def change
    add_column :tutors, :bfl, :string
  end
end
