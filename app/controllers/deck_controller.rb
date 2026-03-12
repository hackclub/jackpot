class DeckController < ApplicationController
   before_action :authenticate_user!
   before_action :authenticate_admin!, only: [:approve_project_admin, :reject_project_admin]

  def index
    projects = current_user.projects.order(position: :asc).to_a
    project_ids = projects.map(&:id)
    
    all_journal_entries = project_ids.present? ? current_user.journal_entries.where(project_id: project_ids).to_a : []
    journal_by_project_id = all_journal_entries.group_by(&:project_id)

    service = HackatimeService.new
    start_date = Date.new(2026, 2, 14)
    hackatime_id = current_user.slack_id || current_user.hack_club_id
    Rails.logger.info("DeckController#index: user=#{current_user.id}, slack_id=#{current_user.slack_id}, hack_club_id=#{current_user.hack_club_id}, hackatime_id=#{hackatime_id}")

     @projects = projects.map.with_index do |project, index|
       linked = project.hackatime_projects || []
       hackatime_hours = linked.sum do |hp_name|
         hours = service.get_project_hours(hackatime_id, hp_name, start_date: start_date)
         Rails.logger.info("  project[#{index}] #{hp_name}: #{hours}h from hackatime")
         hours
       end

       project_journals = journal_by_project_id[project.id] || []
       journal_hours = project_journals.sum(&:hours_worked).to_f
       total_hours = hackatime_hours + journal_hours
       Rails.logger.info("  project[#{index}]: hackatime=#{hackatime_hours}h + journal=#{journal_hours}h = #{total_hours}h")

       project_hash = {
         "id" => project.id,
         "name" => project.name,
         "description" => project.description,
         "project_type" => project.project_type,
         "code_url" => project.code_url,
         "playable_url" => project.playable_url,
         "hackatime_projects" => project.hackatime_projects || [],
         "hours" => total_hours,
         "hackatime_hours" => hackatime_hours,
         "journal_hours" => journal_hours,
         "shipped" => project.shipped,
         "shipped_at" => project.shipped_at&.iso8601,
         "status" => project.status,
         "reviewed" => project.reviewed,
         "reviewed_at" => project.reviewed_at&.iso8601,
         "approved_hours" => project.approved_hours,
         "hour_justification" => project.hour_justification,
         "admin_feedback" => project.admin_feedback,
         "chips_earned" => project.chips_earned,
         "banner_url" => project.banner_url,
         "created_at" => project.created_at&.iso8601
       }
       project_hash
     end

    empty_count = [ 4 - @projects.size, 0 ].max
    @projects += Array.new(empty_count, nil)

    @hackatime_projects = service.get_user_projects(hackatime_id)

    if Rails.env.development? && request.local?
      # Localhost convenience: skip tutorial entirely.
      current_user.update!(tutorial_completed: true) unless current_user.tutorial_completed?
      @show_tutorial = false
    else
      @show_tutorial = Rails.application.config.x.tutorial_on_every_login || !current_user.tutorial_completed?
    end
  end

  def save_project
    project_name = params[:project_name].to_s.strip
    project_description = params[:project_description].to_s.strip
    project_type = params[:project_type].to_s.strip
    playable_url = params[:playable_url].to_s.strip
    code_url = params[:code_url].to_s.strip
    banner_url = params[:banner_url].to_s.strip
    hackatime_projects = Array(params[:hackatime_projects]).map(&:strip).reject(&:blank?)

    if code_url.start_with?('[') || code_url.start_with?('{')
      return render json: { error: "Code URL is invalid" }, status: :unprocessable_entity
    end
    if playable_url.start_with?('[') || playable_url.start_with?('{')
      return render json: { error: "Playable URL is invalid" }, status: :unprocessable_entity
    end

    project_index = params[:project_index].to_i
    is_new = false
    project = nil
    projects_count = current_user.projects.count

    if params[:project_index].present? && project_index >= 0
      project = current_user.projects.order(position: :asc)[project_index]
      if project
        project.update!(
          name: project_name.presence || "Project #{projects_count + 1}",
          description: project_description,
          project_type: project_type,
          playable_url: playable_url,
          code_url: code_url,
          banner_url: banner_url,
          hackatime_projects: hackatime_projects
        )
      end
    end

    if project.nil?
      project = current_user.projects.create!(
        name: project_name.presence || "Project #{projects_count + 1}",
        description: project_description,
        project_type: project_type,
        playable_url: playable_url,
        code_url: code_url,
        banner_url: banner_url,
        hackatime_projects: hackatime_projects
      )
      project_index = project.position
      is_new = true
    end

    if request.xhr?
      render json: { success: true, project_index: project_index, is_new: is_new }
    else
      redirect_to deck_path
    end
  rescue => e
    Rails.logger.error("Error saving project: #{e.message}\n#{e.backtrace.join("\n")}")
    if request.xhr?
      render json: { error: "Error saving project: #{e.message}" }, status: :unprocessable_entity
    else
      flash[:alert] = "Error saving project"
      redirect_to deck_path
    end
  end

  def ship_project
    project_index = params[:project_index].to_i
    project = current_user.projects.order(position: :asc)[project_index]

    if project
      if project.playable_url.blank? || project.code_url.blank? || project.banner_url.blank?
        if request.xhr?
          return render json: { error: "Playable URL, Code URL, and Banner image are required to ship" }, status: :unprocessable_entity
        else
          flash[:alert] = "Playable URL, Code URL, and Banner image are required to ship"
          return redirect_to deck_path
        end
      end

      project.update!(
        shipped: true,
        status: "pending",
        shipped_at: Time.current
      )
    end

    if request.xhr?
      render json: { success: true }
    else
      redirect_to deck_path
    end
  rescue => e
    Rails.logger.error("Error shipping project: #{e.message}\n#{e.backtrace.join("\n")}")
    if request.xhr?
      render json: { error: "Error shipping project: #{e.message}" }, status: :unprocessable_entity
    else
      flash[:alert] = "Error shipping project"
      redirect_to deck_path
    end
  end

   def delete_project
     project_index = params[:project_index].to_i
     project = current_user.projects.order(position: :asc)[project_index]

     if project
       if project.shipped
         if request.xhr?
           return render json: { error: "Cannot delete shipped projects" }, status: :unprocessable_entity
         else
           flash[:alert] = "Cannot delete shipped projects"
           return redirect_to deck_path
         end
       end

       project.destroy!
     end

     if request.xhr?
       render json: { success: true }
     else
       redirect_to deck_path
     end
   rescue => e
     Rails.logger.error("Error deleting project: #{e.message}\n#{e.backtrace.join("\n")}")
     if request.xhr?
       render json: { error: "Error deleting project: #{e.message}" }, status: :unprocessable_entity
     else
       flash[:alert] = "Error deleting project"
       redirect_to deck_path
     end
   end

  def complete_tutorial
    current_user.update!(tutorial_completed: true)
    head :ok
  end

  def create_journal_entry
    project_index = params[:project_index].to_i
    projects = current_user.projects.order(position: :asc).to_a || []

    if !project_index.between?(0, projects.size - 1)
      return render json: { error: "Invalid project index" }, status: :unprocessable_entity
    end

    project = projects[project_index]
    project_name = project.name

    entry = current_user.journal_entries.create!(
      project_id: project.id,
      project_name: project_name,
      project_index: project_index,
      time_done: params[:time_done],
      hours_worked: params[:hours_worked],
      description: params[:description],
      tools_used: Array(params[:tools_used]).map(&:strip).reject(&:blank?)
    )

    render json: entry
  rescue => e
    Rails.logger.error("Error creating journal entry: #{e.message}\n#{e.backtrace.join("\n")}")
    render json: { error: "Error creating journal entry: #{e.message}" }, status: :unprocessable_entity
  end

  def get_journal_entries
    project_index = params[:project_index].to_i
    entries = current_user.journal_entries.for_project(project_index).order(created_at: :desc)
    render json: entries
  end

  def upload_image
    file = params[:file]
    unless file.is_a?(ActionDispatch::Http::UploadedFile)
      return render json: { error: "No file provided" }, status: :unprocessable_entity
    end

    unless file.content_type.start_with?("image/")
      return render json: { error: "Only image files are allowed" }, status: :unprocessable_entity
    end

    if file.size > 10.megabytes
      return render json: { error: "File too large (max 10MB)" }, status: :unprocessable_entity
    end

    cdn = Rails.application.credentials.cdn
    unless cdn
      return render json: { error: "Image uploads not configured" }, status: :service_unavailable
    end

    ext = File.extname(file.original_filename).downcase
    key = "journal-images/#{current_user.id}/#{SecureRandom.uuid}#{ext}"

    client = Aws::S3::Client.new(
      access_key_id: cdn[:key_id],
      secret_access_key: cdn[:secret_key],
      endpoint: cdn[:endpoint],
      region: "auto",
      force_path_style: true
    )

    client.put_object(
      bucket: cdn[:bucket],
      key: key,
      body: file.read,
      content_type: file.content_type,
      acl: "public-read"
    )

    endpoint = cdn[:endpoint].chomp("/")
    url = "#{endpoint}/#{cdn[:bucket]}/#{key}"

    render json: { url: url }
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.error("S3 upload error: #{e.message}")
    render json: { error: "Upload failed" }, status: :internal_server_error
  end

  def approve_project_admin
    user_id = params[:user_id]
    project_index = params[:project_index].to_i
    approved_hours = params[:approved_hours].to_f
    justification = params[:hour_justification]
    feedback = params[:feedback]

    user = User.find(user_id)
    chips_earned = (approved_hours * 50).round(2)

    Rails.logger.info "Approving project for user #{user_id}: #{approved_hours} hours = #{chips_earned} chips"

    begin
      if user.approve_project(project_index, approved_hours, justification, feedback)
        project = user.projects.order(position: :asc)[project_index]
        if project
          project.update!(
            reviewed: true,
            reviewed_at: Time.current,
            status: "approved",
            approved_hours: approved_hours,
            hour_justification: justification,
            admin_feedback: feedback,
            chips_earned: chips_earned,
            reviewed_by_user_id: current_user.id
          )
        end
        Rails.logger.info "Project approved. User #{user_id} earned #{chips_earned} chips. New balance: #{user.chip_am}"
        render json: { success: true, message: "Project approved", chips_earned: chips_earned }
      else
        Rails.logger.error "Failed to approve project"
        render json: { error: "Could not approve project" }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error approving project: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "Error: #{e.message}" }, status: :unprocessable_entity
    end
  end

  def reject_project_admin
    user_id = params[:user_id]
    project_index = params[:project_index].to_i
    feedback = params[:feedback]

    user = User.find(user_id)

    Rails.logger.info "Rejecting project for user #{user_id}"

    begin
      if user.reject_project(project_index, feedback)
        project = user.projects.order(position: :asc)[project_index]
        if project
          project.update!(
            reviewed: true,
            reviewed_at: Time.current,
            status: "rejected",
            admin_feedback: feedback,
            reviewed_by_user_id: current_user.id
          )
        end
        Rails.logger.info "Project rejected for user #{user_id}"
        render json: { success: true, message: "Project rejected" }
      else
        Rails.logger.error "Failed to reject project"
        render json: { error: "Could not reject project" }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error rejecting project: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "Error: #{e.message}" }, status: :unprocessable_entity
    end
  end

  private

  def authenticate_admin!
    redirect_to root_path, alert: "Admin access required" unless admin?
  end
end
