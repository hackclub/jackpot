class CreateYswsProjectSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :ysws_project_submissions do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.string :airtable_id
      t.date :synced_at

      t.string :code_url
      t.string :playable_url
      t.text :description
      t.string :banner_url
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :slack_id
      t.string :github_username
      t.string :address_line_1
      t.string :address_line_2
      t.string :city
      t.string :state
      t.string :country
      t.string :postal_code
      t.string :birthday
      t.decimal :approved_hours, precision: 10, scale: 2
      t.text :optional_override_hours_spent_justification

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          INSERT INTO ysws_project_submissions (
            project_id, airtable_id, synced_at, created_at, updated_at
          )
          SELECT id, shipped_airtable_id, shipped_synced_at, NOW(), NOW()
          FROM projects
          WHERE shipped = TRUE
        SQL
      end
    end
  end
end
