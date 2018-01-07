class RemoveTutorFromSessions < ActiveRecord::Migration
  def change
    remove_reference :sessions, :tutor, index: true
  end
end
