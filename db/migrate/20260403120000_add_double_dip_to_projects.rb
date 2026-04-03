# frozen_string_literal: true

class AddDoubleDipToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :double_dip, :boolean, default: false, null: false
  end
end
