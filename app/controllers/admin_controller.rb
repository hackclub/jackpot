class AdminController < ApplicationController
  skip_before_action :check_access_flipper
  before_action :authenticate_admin!

  def index
    Rails.logger.info "Current user hack_club_id: #{current_user&.hack_club_id}"
    Rails.logger.info "Is admin? #{admin?}"
  end

  def review
    @all_users = User.where("projects IS NOT NULL AND projects != '[]'")
    @projects_for_review = []
    @all_projects = []
    
    service = HackatimeService.new
    start_date = Date.new(2026, 2, 14)
    
    @all_users.each do |user|
      projects = user.projects || []
      projects.each_with_index do |project, index|
        # Skip nil projects
        next if project.nil?
        
        # Calculate hours (same as deck_controller)
        total_hours = calculate_project_hours(user, project, index, service, start_date)
        journal_entries = user.journal_entries.for_project(index)
        
        project_item = {
          user: user,
          project: project,
          project_index: index,
          hours: total_hours,
          journal_entries: journal_entries
        }
        
        @all_projects << project_item
        
        if project["shipped"] && !project["reviewed"]
          @projects_for_review << project_item
        end
      end
    end
  end
  
  private
  
  def calculate_project_hours(user, project, project_index, service, start_date)
    hackatime_id = user.slack_id || user.hack_club_id
    hackatime_hours = 0
    
    if hackatime_id && project["hackatime_projects"]
      linked = project["hackatime_projects"] || []
      hackatime_hours = linked.sum do |hp_name|
        service.get_project_hours(hackatime_id, hp_name, start_date: start_date)
      end
    end
    
    journal_hours = user.journal_entries.for_project(project_index).sum(:hours_worked).to_f
    hackatime_hours + journal_hours
  end

  def authenticate_admin!
    unless admin?
      Rails.logger.warn "Non-admin tried to access admin panel. User: #{current_user&.hack_club_id || 'not logged in'}"
      redirect_to root_path, alert: "Access denied. Admin only."
    end
  end
end
