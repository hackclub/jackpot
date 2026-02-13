class AddTutorialCompletedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :tutorial_completed, :boolean, default: false, null: false
  end
end
