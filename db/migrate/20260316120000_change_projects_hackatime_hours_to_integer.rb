# frozen_string_literal: true

class ChangeProjectsHackatimeHoursToInteger < ActiveRecord::Migration[8.1]
  def up
    change_column :projects, :hackatime_hours, :integer,
      default: 0, null: false,
      using: "ROUND(hackatime_hours::numeric)::integer"
  end

  def down
    change_column :projects, :hackatime_hours, :decimal,
      precision: 10, scale: 2, default: "0.0", null: false
  end
end
