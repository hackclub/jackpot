class ChangeProjectsHourJustificationToText < ActiveRecord::Migration[8.1]
  def up
    change_column :projects, :hour_justification, :text
  end

  def down
    change_column :projects, :hour_justification, :string
  end
end
