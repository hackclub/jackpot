class AddBannerUrlToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :banner_url, :string
  end
end
