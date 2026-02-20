class Project < ApplicationRecord
  belongs_to :user
  has_many :journal_entries, foreign_key: :user_id, primary_key: :user_id, dependent: :destroy

  validates :name, :user_id, presence: true
  validate :safe_urls
  
  scope :shipped, -> { where(shipped: true) }
  scope :reviewed, -> { where(reviewed: true) }
  scope :pending_review, -> { where(shipped: true, reviewed: false) }
  
  before_save :set_position, if: :position.nil?
  
  def set_position
    self.position = user.projects.count
  end
  
  def self.from_json(user, json_projects)
    return [] unless json_projects.present?
    
    json_projects.each_with_index do |project_data, index|
      next if project_data.nil?
      
      project = user.projects.find_or_create_by(name: project_data["name"], created_at: project_data["created_at"]) do |p|
        p.description = project_data["description"]
        p.project_type = project_data["project_type"]
        p.code_url = project_data["code_url"]
        p.playable_url = project_data["playable_url"]
        p.hackatime_projects = project_data["hackatime_projects"] || []
        p.shipped = project_data["shipped"] || false
        p.shipped_at = project_data["shipped_at"]
        p.status = project_data["status"] || "pending"
        p.reviewed = project_data["reviewed"] || false
        p.reviewed_at = project_data["reviewed_at"]
        p.approved_hours = project_data["approved_hours"]
        p.hour_justification = project_data["hour_justification"]
        p.admin_feedback = project_data["admin_feedback"]
        p.chips_earned = project_data["chips_earned"]
        p.position = index
      end
      project.save! if project.changed?
    end
  end
  
  def approve(approved_hours, justification = nil, feedback = nil)
    self.reviewed = true
    self.status = "approved"
    self.approved_hours = approved_hours.to_f
    self.hour_justification = justification
    self.admin_feedback = feedback
    self.reviewed_at = Time.current
    self.chips_earned = (approved_hours.to_f * 35).round(2)
    
    user.chip_am = (user.chip_am || 0) + chips_earned
    
    transaction do
      save!
      user.save!
    end
  end
  
  def reject(feedback = nil)
    self.reviewed = true
    self.status = "rejected"
    self.admin_feedback = feedback
    self.reviewed_at = Time.current
    save!
  end

  private

  def safe_urls
    %i[code_url playable_url].each do |attr|
      value = send(attr).to_s.strip
      next if value.blank?
      unless value.match?(/\Ahttps?:\/\//i)
        errors.add(attr, "must start with http:// or https://")
      end
    end
  end
end
