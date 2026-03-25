# frozen_string_literal: true

class AddShippingQueueSnapshotTotalHoursToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :shipping_queue_snapshot_total_hours, :decimal, precision: 10, scale: 2

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE projects
          SET shipping_queue_snapshot_total_hours = total_hours
          WHERE shipped = TRUE AND status = 'in-review' AND reviewed = FALSE
            AND shipping_queue_snapshot_total_hours IS NULL
        SQL
      end
    end
  end
end
