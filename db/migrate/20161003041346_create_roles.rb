class CreateRoles < ActiveRecord::Migration
  def change
    create_table :roles do |t|
      t.belongs_to :session, index: true
      t.belongs_to :student, index: true

      t.timestamps
    end
  end
end
