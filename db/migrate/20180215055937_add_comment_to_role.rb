class AddCommentToRole < ActiveRecord::Migration
  def change
    add_column :roles, :comment, :text
  end
end
