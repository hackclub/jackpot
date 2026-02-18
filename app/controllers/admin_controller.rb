class AdminController < ApplicationController
  skip_before_action :check_access_flipper
  before_action :authenticate_admin!

  def index
    Rails.logger.info "Current user hack_club_id: #{current_user&.hack_club_id}"
    Rails.logger.info "Is admin? #{admin?}"
    cleanup_corrupted_projects
  end

  def review
    begin
      Rails.logger.info "=== AdminController#review START ==="
      @all_users = User.where("projects IS NOT NULL AND projects != '[]'")
      Rails.logger.info "Found #{@all_users.count} users with projects"
      @projects_for_review = []
      @all_projects = []
      
      service = HackatimeService.new
      start_date = Date.new(2026, 2, 14)
      
      @all_users.each do |user|
        begin
          Rails.logger.info "Processing user #{user.id} (#{user.email})"
          projects = user.projects || []
          Rails.logger.info "  User has #{projects.length} projects"
          
          projects.each_with_index do |project, index|
            Rails.logger.info "  Processing project[#{index}]: #{project.inspect}"
            next if project.nil?
            
            begin
              # Calculate hours (same as deck_controller)
              Rails.logger.info "    Calculating hours for project[#{index}]..."
              total_hours = calculate_project_hours(user, project, index, service, start_date)
              Rails.logger.info "    calculate_project_hours returned: #{total_hours.inspect} (class: #{total_hours.class})"
              
              total_hours = 0.0 if total_hours.nil?
              Rails.logger.info "    After nil check: #{total_hours.inspect}"
              
              total_hours = total_hours.to_f
              Rails.logger.info "    After to_f: #{total_hours.inspect} (class: #{total_hours.class})"
              
              journal_entries = user.journal_entries.for_project(index) rescue []
              Rails.logger.info "    Journal entries: #{journal_entries.length} found"
              
              project_item = {
                user: user,
                project: project,
                project_index: index,
                hours: total_hours,
                journal_entries: journal_entries || []
              }
              
              Rails.logger.info "    Created project_item with hours=#{project_item[:hours].inspect}"
              @all_projects << project_item
              
              if project["shipped"].to_s == "true" && project["reviewed"].to_s != "true"
                Rails.logger.info "    Adding to @projects_for_review"
                @projects_for_review << project_item
              end
            rescue => e
              Rails.logger.error("ERROR processing project[#{index}] for user #{user.id}: #{e.class} - #{e.message}")
              Rails.logger.error(e.backtrace.join("\n"))
            end
          end
        rescue => e
          Rails.logger.error("ERROR processing user #{user.id}: #{e.class} - #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
        end
      end
      
      Rails.logger.info "=== AdminController#review END ==="
      Rails.logger.info "Total @all_projects: #{@all_projects.length}"
      Rails.logger.info "Total @projects_for_review: #{@projects_for_review.length}"
    rescue => e
      Rails.logger.error("FATAL ERROR in review action: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      @all_users = []
      @projects_for_review = []
      @all_projects = []
    end
  end
  
  private
  
  def cleanup_corrupted_projects
    User.where("projects IS NOT NULL AND projects != '[]'").find_each do |user|
      projects = user.projects || []
      modified = false
      
      projects.each do |project|
        next if project.nil?
        
        code_url = project["code_url"].to_s
        playable_url = project["playable_url"].to_s
        
        if (code_url.start_with?('[') || code_url.start_with?('{')) &&
           (playable_url.start_with?('[') || playable_url.start_with?('{'))
          Rails.logger.warn("Found corrupted project for user #{user.id}: #{project['name']}")
          project["code_url"] = ""
          project["playable_url"] = ""
          modified = true
        elsif code_url.start_with?('[') || code_url.start_with?('{')
          Rails.logger.warn("Cleaning code_url for user #{user.id} project #{project['name']}")
          project["code_url"] = ""
          modified = true
        elsif playable_url.start_with?('[') || playable_url.start_with?('{')
          Rails.logger.warn("Cleaning playable_url for user #{user.id} project #{project['name']}")
          project["playable_url"] = ""
          modified = true
        end
      end
      
      user.update!(projects: projects) if modified
    end
  end
  
  def calculate_project_hours(user, project, project_index, service, start_date)
    Rails.logger.info "        [calculate_project_hours] START user=#{user.id}, project_index=#{project_index}"
    return 0.0 if project.nil?
    
    begin
      hackatime_id = user.slack_id || user.hack_club_id
      Rails.logger.info "        [calculate_project_hours] hackatime_id=#{hackatime_id}"
      hackatime_hours = 0.0
      
      if hackatime_id && project["hackatime_projects"]
        linked = project["hackatime_projects"] || []
        Rails.logger.info("        [calculate_project_hours] Getting hours for #{linked.length} hackatime projects: #{linked.inspect}")
        hackatime_hours = linked.sum do |hp_name|
          hours = service.get_project_hours(hackatime_id, hp_name, start_date: start_date)
          Rails.logger.info("        [calculate_project_hours]   #{hp_name}: #{hours.inspect} (class: #{hours.class})")
          hours = 0.0 if hours.nil?
          hours
        end
        Rails.logger.info("        [calculate_project_hours] Total hackatime_hours: #{hackatime_hours.inspect} (class: #{hackatime_hours.class})")
      else
        Rails.logger.info("        [calculate_project_hours] No hackatime projects, hackatime_id=#{hackatime_id}, has hackatime_projects=#{project['hackatime_projects'].present?}")
      end
      
      Rails.logger.info("        [calculate_project_hours] Getting journal entries for project_index=#{project_index}")
      journal_sum = user.journal_entries.for_project(project_index).sum(:hours_worked)
      Rails.logger.info("        [calculate_project_hours] journal_sum: #{journal_sum.inspect} (class: #{journal_sum.class})")
      journal_hours = journal_sum.to_f || 0.0
      Rails.logger.info("        [calculate_project_hours] journal_hours: #{journal_hours.inspect} (class: #{journal_hours.class})")
      
      total = (hackatime_hours || 0.0) + (journal_hours || 0.0)
      Rails.logger.info("        [calculate_project_hours] total: #{hackatime_hours} + #{journal_hours} = #{total} (class: #{total.class})")
      total
    rescue => e
      Rails.logger.error("        [calculate_project_hours] ERROR: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      0.0
    end
  end

  def authenticate_admin!
    unless admin?
      Rails.logger.warn "Non-admin tried to access admin panel. User: #{current_user&.hack_club_id || 'not logged in'}"
      redirect_to root_path, alert: "Access denied. Admin only."
    end
  end
end
