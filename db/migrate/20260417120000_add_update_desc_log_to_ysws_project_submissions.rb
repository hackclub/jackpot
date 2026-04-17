# frozen_string_literal: true

class AddUpdateDescLogToYswsProjectSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :ysws_project_submissions, :update_desc_log, :text
  end
end
