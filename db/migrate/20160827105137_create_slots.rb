class CreateSlots < ActiveRecord::Migration
  def change
    create_table :slots do |t|
      t.datetime :timeslot
      t.string :location
      t.text :comment

      t.timestamps
    end
  end
end
