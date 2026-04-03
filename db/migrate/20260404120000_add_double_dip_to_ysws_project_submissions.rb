# frozen_string_literal: true

class AddDoubleDipToYswsProjectSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :ysws_project_submissions, :double_dip, :boolean, default: false, null: false
  end
end
