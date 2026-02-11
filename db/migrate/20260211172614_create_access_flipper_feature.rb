class CreateAccessFlipperFeature < ActiveRecord::Migration[8.1]
  def up
    # Ensure the access flipper feature exists and is enabled globally
    # This allows all existing users to continue accessing the app
    Flipper.enable(:access) unless Flipper.exist?(:access)
  end

  def down
    # No rollback needed
  end
end
