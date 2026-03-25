# frozen_string_literal: true

class AddPastApprovedHoursAndFirstShippedAtToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :past_approved_hours, :decimal, precision: 10, scale: 2, default: "0.0", null: false
    add_column :projects, :first_shipped_at, :datetime

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE projects
          SET past_approved_hours = COALESCE(approved_hours, 0)
          WHERE reviewed = TRUE AND status = 'approved' AND approved_hours IS NOT NULL
        SQL

        execute <<~SQL.squish
          UPDATE projects
          SET first_shipped_at = shipped_at
          WHERE shipped_at IS NOT NULL AND first_shipped_at IS NULL
        SQL
      end
    end
  end
end
