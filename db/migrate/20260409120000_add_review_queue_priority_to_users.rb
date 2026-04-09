# frozen_string_literal: true

class AddReviewQueuePriorityToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :review_queue_priority, :boolean, default: false, null: false
  end
end
