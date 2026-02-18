class JournalEntry < ApplicationRecord
  belongs_to :user, foreign_key: :user_id, primary_key: :id
  belongs_to :project, optional: true

  validates :user_id, :project_name, :project_index, presence: true
  validates :hours_worked, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  scope :for_project, ->(project_index) { where(project_index: project_index) }
  scope :for_project_id, ->(project_id) { where(project_id: project_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }

  def self.for_user_and_project(user_id, project_index)
    for_user(user_id).for_project(project_index).order(created_at: :desc)
  end
  
  def self.for_user_and_project_id(user_id, project_id)
    for_user(user_id).for_project_id(project_id).order(created_at: :desc)
  end
end
