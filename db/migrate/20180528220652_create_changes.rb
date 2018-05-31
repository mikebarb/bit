class CreateChanges < ActiveRecord::Migration
  def change
    create_table :changes do |t|
      t.integer :user
      t.string :table
      t.integer :rid
      t.string :field
      t.text :value
      t.datetime :modified

      t.timestamps null: false
    end
    add_index "changes", ["table"], name: "index_changes_on_table", using: :btree
    add_index "changes", ["rid"], name: "index_changes_on_rid", using: :btree
  end
end
