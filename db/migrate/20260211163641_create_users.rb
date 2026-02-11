class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :hack_club_id
      t.string :display_name
      t.string :email
      t.text :access_token_ciphertext
      t.integer :role
      t.string :provider
      t.datetime :last_sign_in_at

      t.timestamps
    end
  end
end
