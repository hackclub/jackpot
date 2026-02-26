class AddColumnsToProjects < ActiveRecord::Migration[8.1]
  def change
    unless table_exists?(:projects)
      create_table :projects do |t|
        t.references :user, null: false, foreign_key: true
        t.string :name, null: false
        t.text :description
        t.string :project_type
        t.timestamps
      end

      add_index :projects, %i[user_id name] unless index_exists?(:projects, %i[user_id name])
    end

    add_column :projects, :code_url, :string unless column_exists?(:projects, :code_url)
    add_column :projects, :playable_url, :string unless column_exists?(:projects, :playable_url)
    add_column :projects, :hackatime_projects, :json, default: [], null: false unless column_exists?(:projects, :hackatime_projects)
    add_column :projects, :shipped, :boolean, default: false, null: false unless column_exists?(:projects, :shipped)
    add_column :projects, :shipped_at, :datetime unless column_exists?(:projects, :shipped_at)
    add_column :projects, :status, :string, default: "pending" unless column_exists?(:projects, :status)
    add_column :projects, :reviewed, :boolean, default: false, null: false unless column_exists?(:projects, :reviewed)
    add_column :projects, :reviewed_at, :datetime unless column_exists?(:projects, :reviewed_at)
    add_column :projects, :approved_hours, :decimal, precision: 10, scale: 2 unless column_exists?(:projects, :approved_hours)
    add_column :projects, :hour_justification, :string unless column_exists?(:projects, :hour_justification)
    add_column :projects, :admin_feedback, :text unless column_exists?(:projects, :admin_feedback)
    add_column :projects, :chips_earned, :decimal, precision: 10, scale: 2 unless column_exists?(:projects, :chips_earned)
    add_column :projects, :position, :integer, default: 0 unless column_exists?(:projects, :position)
  end
end
