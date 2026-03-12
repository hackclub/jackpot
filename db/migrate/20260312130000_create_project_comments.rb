class CreateProjectComments < ActiveRecord::Migration[8.1]
  def change
    create_table :project_comments do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end

    add_index :project_comments, %i[project_id created_at]
  end
end

