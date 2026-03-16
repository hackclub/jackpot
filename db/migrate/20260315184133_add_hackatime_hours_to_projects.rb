class AddHackatimeHoursToProjects < ActiveRecord::Migration[8.1]
  def up
    change_column :projects, :hackatime_hours, :decimal, precision: 10, scale: 2, default: 0
  end

  def down
    change_column :projects, :hackatime_hours, :float, default: 0
  end
end
