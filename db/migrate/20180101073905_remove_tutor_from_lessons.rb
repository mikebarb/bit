class RemoveTutorFromLessons < ActiveRecord::Migration
  def change
    remove_reference :lessons, :tutor, index: true
  end
end
