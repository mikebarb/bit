class AddStatusToTutors < ActiveRecord::Migration
  def change
    add_column :tutors, :status, :string
    add_column :tutors, :email, :string
    add_column :tutors, :phone, :string
  end
end
