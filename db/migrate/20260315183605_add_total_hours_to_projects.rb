class AddTotalHoursToProjects < ActiveRecord::Migration[8.1]
  def up
    add_column :projects, :total_hours, :decimal, precision: 10, scale: 2, default: 0 unless column_exists?(:projects, :total_hours)
  end

  def down
    remove_column :projects, :total_hours if column_exists?(:projects, :total_hours)
  end
end
