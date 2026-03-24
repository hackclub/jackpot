# frozen_string_literal: true

class AddApproverDisplayNameToProjects < ActiveRecord::Migration[8.1]
  def up
    add_column :projects, :approver_display_name, :string

    say_with_time "Backfill approver_display_name for approved projects" do
      Project.reset_column_information
      Project.where(status: "approved", reviewed: true).where.not(reviewed_by_user_id: nil).find_each do |p|
        next if p.read_attribute(:approver_display_name).present?

        u = User.find_by(id: p.reviewed_by_user_id)
        next unless u

        label = u.read_attribute(:display_name).presence ||
                u.read_attribute(:email).to_s.split("@").first.presence
        p.update_column(:approver_display_name, label) if label.present?
      end
    end
  end

  def down
    remove_column :projects, :approver_display_name
  end
end
