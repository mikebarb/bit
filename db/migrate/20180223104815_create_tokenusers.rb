class CreateTokenusers < ActiveRecord::Migration
  def change
    create_table :tokenusers do |t|
      t.text :client_id
      t.text :token_json

      t.timestamps null: false
    end
  end
end
