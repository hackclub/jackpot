# frozen_string_literal: true

class ExpandUserRoles < ActiveRecord::Migration[8.1]
  # Previous enum: user=0, admin=1
  # New enum: user=0, reviewer=1, admin=2, super_admin=3
  def up
    execute "UPDATE users SET role = 2 WHERE role = 1"
  end

  def down
    execute "UPDATE users SET role = 0 WHERE role = 1"
    execute "UPDATE users SET role = 1 WHERE role = 2"
    execute "UPDATE users SET role = 1 WHERE role = 3"
  end
end
