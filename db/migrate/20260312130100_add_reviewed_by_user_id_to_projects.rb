class AddReviewedByUserIdToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :reviewed_by_user_id, :bigint
    add_index :projects, :reviewed_by_user_id
    add_foreign_key :projects, :users, column: :reviewed_by_user_id
  end
end
