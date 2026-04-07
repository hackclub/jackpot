# frozen_string_literal: true

class CreateUserAdminNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :user_admin_notes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.string :note_type, null: false, default: "general"
      t.text :body, null: false
      t.decimal :chip_am_before, precision: 10, scale: 1
      t.decimal :chip_am_after, precision: 10, scale: 1
      t.timestamps
    end
  end
end
