class AddGithubUsernameToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :github_username, :string
  end
end
