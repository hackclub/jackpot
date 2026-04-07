# frozen_string_literal: true

class AddFraudCheckToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :fraud_check, :boolean, default: false, null: false
  end
end
