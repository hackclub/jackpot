class AddTotalHoursToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :total_hours, :decimal, precision: 10, scale: 2, default: 0 unless column_exists?(:projects, :total_hours)
  end
end
