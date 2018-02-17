class AddCommentToTutrole < ActiveRecord::Migration
  def change
    add_column :tutroles, :comment, :text
  end
end
