class CreateTutors < ActiveRecord::Migration
  def change
    create_table :tutors do |t|
      t.string :gname
      t.string :sname
      t.string :pname
      t.string :initials
      t.string :sex
      t.text :comment

      t.timestamps
    end
  end
end
