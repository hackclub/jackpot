class CreateRsvpTable < ActiveRecord::Migration[8.1]
  def change
    create_table :rsvp_tables do |t|
      t.string :email
      t.string :ip
      t.string :user_agent
      t.date :synced_at
      t.string :ref
      t.timestamps
    end
  end
end
