# frozen_string_literal: true

class AddAutomationFirstSubmittedAtToYswsProjectSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :ysws_project_submissions, :automation_first_submitted_at, :datetime
  end
end
