class AddSlackIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :slack_id, :string
  end
end
