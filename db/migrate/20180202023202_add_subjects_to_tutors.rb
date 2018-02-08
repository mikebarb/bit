class AddSubjectsToTutors < ActiveRecord::Migration
  def change
    add_column :tutors, :subjects, :string
    add_index :tutors, :pname, unique: true
  end
end
