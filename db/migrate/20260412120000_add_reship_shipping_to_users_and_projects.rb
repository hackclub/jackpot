# frozen_string_literal: true

class AddReshipShippingToUsersAndProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :reship_shipping_enabled, :boolean, default: false, null: false
    add_column :projects, :reship_submission, :boolean, default: false, null: false
  end
end
