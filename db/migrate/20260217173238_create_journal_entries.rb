class CreateJournalEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :journal_entries do |t|
      t.bigint :user_id, null: false
      t.string :project_name, null: false
      t.integer :project_index, null: false
      t.datetime :time_done
      t.decimal :hours_worked, precision: 5, scale: 2
      t.text :description
      t.string :tools_used, array: true, default: []

      t.timestamps
    end

    add_foreign_key :journal_entries, :users
    add_index :journal_entries, [:user_id, :project_index]
  end
end
