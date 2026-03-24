# frozen_string_literal: true

class AddShipStatusToYswsProjectSubmissions < ActiveRecord::Migration[8.1]
  def up
    add_column :ysws_project_submissions, :ship_status, :string, null: false, default: "Pending"

    execute <<~SQL.squish
      UPDATE ysws_project_submissions AS s
      SET ship_status = CASE
        WHEN p.reviewed = TRUE AND p.status = 'approved' THEN 'Approved'
        WHEN p.reviewed = TRUE AND p.status = 'rejected' THEN 'Rejected'
        ELSE 'Pending'
      END
      FROM projects AS p
      WHERE p.id = s.project_id
    SQL

    # Rejected projects should not stay in the shipped pipeline; remove submission rows and return project to deck.
    execute <<~SQL.squish
      DELETE FROM ysws_project_submissions
      WHERE project_id IN (
        SELECT id FROM projects
        WHERE shipped = TRUE AND reviewed = TRUE AND status = 'rejected'
      )
    SQL

    execute <<~SQL.squish
      UPDATE projects
      SET
        shipped = FALSE,
        shipped_at = NULL,
        shipped_airtable_id = NULL,
        shipped_synced_at = NULL,
        status = 'pending',
        reviewed = FALSE,
        reviewed_at = NULL,
        reviewed_by_user_id = NULL
      WHERE shipped = TRUE AND reviewed = TRUE AND status = 'rejected'
    SQL
  end

  def down
    remove_column :ysws_project_submissions, :ship_status
  end
end
