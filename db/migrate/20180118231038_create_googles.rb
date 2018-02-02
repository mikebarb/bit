class CreateGoogles < ActiveRecord::Migration
  def change
    create_table :googles do |t|
      t.string :user
      t.string :client_id
      t.string :access_token
      t.string :refresh_token
      t.string :scope

      t.timestamps
    end
  end
end
