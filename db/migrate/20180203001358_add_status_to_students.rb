class AddStatusToStudents < ActiveRecord::Migration
  def change
    add_column :students, :status, :string
    add_column :students, :year, :string
    add_column :students, :study, :string
    add_column :students, :email, :string
    add_column :students, :phone, :string
    add_column :students, :invcode, :string
    add_column :students, :daycode, :string
    add_column :students, :preferences, :string
    add_index :students, :pname, unique: true
  end
end
