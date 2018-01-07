class CreateTutroles < ActiveRecord::Migration
  def change
    create_table :tutroles do |t|
      t.belongs_to :session, index: true
      t.belongs_to :tutor, index: true

      t.timestamps
    end
  end
end
