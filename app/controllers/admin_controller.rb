class AdminController < ApplicationController
  skip_before_action :check_access_flipper
  before_action :authenticate_admin!

  def index
    Rails.logger.info "Current user hack_club_id: #{current_user&.hack_club_id}"
    Rails.logger.info "Is admin? #{admin?}"
    cleanup_corrupted_projects
  end

  def console
  end

  def airtable_sync
    @sync_jobs = [
      { name: "Users", job_class: "Airtable::UserSyncJob", model: User, table_env: "AIRTABLE_USERS_TABLE", table_default: "_users" },
      { name: "Projects", job_class: "Airtable::ProjectSyncJob", model: Project, table_env: "AIRTABLE_PROJECTS_TABLE", table_default: "_projects" },
      { name: "RSVPs", job_class: "Airtable::RsvpSyncJob", model: RsvpTable, table_env: "AIRTABLE_RSVPS_TABLE", table_default: "_rsvps" },
      { name: "Shop Orders", job_class: "Airtable::ShopOrderSyncJob", model: ShopOrder, table_env: "AIRTABLE_SHOP_ORDERS_TABLE", table_default: "_shop_orders" },
      { name: "Shop Items", job_class: "Airtable::ShopItemSyncJob", model: ShopItem, table_env: "AIRTABLE_SHOP_ITEMS_TABLE", table_default: "_shop_items" },
      { name: "Journal Entries", job_class: "Airtable::JournalEntrySyncJob", model: JournalEntry, table_env: "AIRTABLE_JOURNAL_ENTRIES_TABLE", table_default: "_journal_entries" },
      { name: "Project Comments", job_class: "Airtable::ProjectCommentSyncJob", model: ProjectComment, table_env: "AIRTABLE_PROJECT_COMMENTS_TABLE", table_default: "_project_comments" },
      { name: "Shop Item Requests", job_class: "Airtable::ShopItemRequestSyncJob", model: ShopItemRequest, table_env: "AIRTABLE_SHOP_ITEM_REQUESTS_TABLE", table_default: "_shop_item_requests" }
    ]

    @sync_jobs.each do |job|
      model = job[:model]
      job[:total] = model.count
      job[:synced] = model.where.not(airtable_id: nil).count
      job[:unsynced] = job[:total] - job[:synced]
      job[:never_synced] = model.where(synced_at: nil).count
      job[:last_synced_at] = model.where.not(synced_at: nil).maximum(:synced_at)
      job[:oldest_sync] = model.where.not(synced_at: nil).minimum(:synced_at)
      job[:airtable_table] = ENV.fetch(job[:table_env], job[:table_default])

      # Check Solid Queue for recent job runs
      job[:pending_jobs] = SolidQueue::Job.where(class_name: job[:job_class], finished_at: nil).count
      job[:last_finished] = SolidQueue::Job.where(class_name: job[:job_class]).where.not(finished_at: nil).order(finished_at: :desc).first
      job[:last_failed] = SolidQueue::FailedExecution.joins(:job).where(solid_queue_jobs: { class_name: job[:job_class] }).order(created_at: :desc).first
    end

    @has_token = (Rails.application.credentials&.airtable&.acces_token || ENV["AIRTABLE_API_KEY"]).present?
    @has_base_id = (Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"]).present?
    @base_id = Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"]

    @recurring_config = begin
      raw = YAML.safe_load(ERB.new(File.read(Rails.root.join("config/recurring.yml"))).result) || {}
      env_config = raw[Rails.env] || raw["production"] || {}
      env_config.select { |key, _| key.to_s.start_with?("airtable") }
    rescue => e
      Rails.logger.warn("Failed to load recurring.yml: #{e.message}")
      {}
    end

    @recurring_tasks_db = begin
      SolidQueue::RecurringTask.where("key LIKE ?", "airtable%").to_a
    rescue
      []
    end
  end

  def force_airtable_sync
    job_classes = [
      Airtable::UserSyncJob,
      Airtable::ProjectSyncJob,
      Airtable::RsvpSyncJob,
      Airtable::ShopOrderSyncJob,
      Airtable::ShopItemSyncJob,
      Airtable::JournalEntrySyncJob,
      Airtable::ProjectCommentSyncJob,
      Airtable::ShopItemRequestSyncJob
    ]

    @sync_results = []

    job_classes.each do |klass|
      job = klass.new
      begin
        job.perform
        @sync_results << { name: klass.name, status: "ok", log: job.sync_log || [] }
      rescue => e
        log = (job.sync_log || []) + [ "EXCEPTION: #{e.class}: #{e.message}", e.backtrace&.first(5)&.join("\n") ].compact
        @sync_results << { name: klass.name, status: "error", log: log }
      end
    end

    render :force_sync_results
  end

  # Executes Ruby code submitted from the admin console.
  # Captures stdout and the return value, with a 30-second timeout.
  def execute_console
    code = params[:code].to_s

    if code.blank?
      return render json: { output: "", result: "No code provided." }
    end

    output = StringIO.new
    result = nil

    begin
      Timeout.timeout(30) do
        old_stdout = $stdout
        $stdout = output

        # rubocop:disable Security/Eval
        result = eval(code, TOPLEVEL_BINDING, "admin_console", 1)
        # rubocop:enable Security/Eval

        $stdout = old_stdout
      end
    rescue Timeout::Error
      $stdout = STDOUT
      return render json: { output: output.string, result: "Error: Execution timed out after 30 seconds." }
    rescue Exception => e
      $stdout = STDOUT
      return render json: { output: output.string, result: "#{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}" }
    end

    render json: { output: output.string, result: result.inspect }
  end

  def items_request
    week_start = Time.current.beginning_of_week
    week_end = Time.current.end_of_week
    @this_week_requests = ShopItemRequest.includes(:user)
      .where(created_at: week_start..week_end)
      .order(created_at: :asc)

    past_requests = ShopItemRequest.includes(:user)
      .where(ShopItemRequest.arel_table[:created_at].lt(week_start))
      .order(created_at: :desc)
    grouped = past_requests.group_by { |r| r.created_at.to_date.beginning_of_week }
    @past_requests_by_week = grouped.sort_by { |week_date, _| -week_date.to_time.to_i }.map do |week_date, requests|
      end_date = week_date + 7.days
      label = "#{week_date.strftime('%B %e').strip}-#{end_date.strftime('%e').strip}".gsub(/\s+/, " ")
      { label: label, week_start: week_date, requests: requests }
    end
  end

  def update_item_request
    request = ShopItemRequest.find(params[:id])
    approved = params[:approved].to_s.in?(%w[1 true yes])
    request.update!(approved: approved)
    redirect_to admin_items_request_path, notice: approved ? "Request marked as approved." : "Request unmarked."
  end

  def review
     begin
       all_db_projects = Project.includes(:user).order(created_at: :desc)
       pending_db_projects = Project.where(shipped: true, status: "in-review", reviewed: false).includes(:user).order(created_at: :desc)

       @projects_for_review = []
       @all_projects = []

       all_db_projects.each do |db_project|
         user = db_project.user
         next unless user

         project_hash = {
           "id" => db_project.id,
           "name" => db_project.name,
           "description" => db_project.description,
           "project_type" => db_project.project_type,
           "code_url" => db_project.code_url,
           "playable_url" => db_project.playable_url,
           "banner_url" => db_project.banner_url,
           "hackatime_projects" => db_project.hackatime_projects || [],
           "shipped" => db_project.shipped,
           "shipped_at" => db_project.shipped_at&.iso8601,
           "status" => db_project.status,
           "reviewed" => db_project.reviewed,
           "reviewed_at" => db_project.reviewed_at&.iso8601,
           "created_at" => db_project.created_at&.iso8601,
           "total_hours" => db_project.total_hours || 0,
           "hours" => db_project.total_hours || 0
         }

         project_item = {
           user: user,
           project: project_hash,
           project_index: db_project.position
         }

         @all_projects << project_item
       end

       pending_db_projects.each do |db_project|
         user = db_project.user
         next unless user

         project_hash = {
           "id" => db_project.id,
           "name" => db_project.name,
           "description" => db_project.description,
           "project_type" => db_project.project_type,
           "code_url" => db_project.code_url,
           "playable_url" => db_project.playable_url,
           "banner_url" => db_project.banner_url,
           "hackatime_projects" => db_project.hackatime_projects || [],
           "shipped" => db_project.shipped,
           "shipped_at" => db_project.shipped_at&.iso8601,
           "status" => db_project.status,
           "reviewed" => db_project.reviewed,
           "reviewed_at" => db_project.reviewed_at&.iso8601,
           "created_at" => db_project.created_at&.iso8601,
           "total_hours" => db_project.total_hours || 0,
           "hours" => db_project.total_hours || 0
         }

         project_item = {
           user: user,
           project: project_hash,
           project_index: db_project.position
         }

         @projects_for_review << project_item
       end
     rescue => e
       Rails.logger.error("FATAL ERROR in review action: #{e.class} - #{e.message}")
       Rails.logger.error(e.backtrace.join("\n"))
       @projects_for_review = []
       @all_projects = []
     end
   end

  def review_project
    begin
      project_id = params[:project_id]
      @project_db = Project.find(project_id)
      @user = @project_db.user

      unless @user
        redirect_to admin_review_path, alert: "Project user not found"
        return
      end

      # Find the project index for this user
      @project_index = @project_db.position

      # Get journal entries
      @journal_entries = @project_db.journal_entries || []
      # Use the project's canonical total_hours so combined hours match what users reported
      @total_hours = (@project_db.total_hours || 0).to_f

      # Project comments (from status page) so admin can see user comments in review
      @project_comments = @project_db.project_comments.includes(:user).order(created_at: :asc)

      # Convert to hash format for view
      @project = {
        "id" => @project_db.id,
        "name" => @project_db.name,
        "description" => @project_db.description,
        "project_type" => @project_db.project_type,
        "code_url" => @project_db.code_url,
        "playable_url" => @project_db.playable_url,
        "banner_url" => @project_db.banner_url,
        "hackatime_projects" => @project_db.hackatime_projects || [],
        "shipped" => @project_db.shipped,
        "shipped_at" => @project_db.shipped_at&.iso8601,
        "status" => @project_db.status,
        "reviewed" => @project_db.reviewed,
        "reviewed_at" => @project_db.reviewed_at&.iso8601,
        "created_at" => @project_db.created_at&.iso8601
      }
    rescue => e
      Rails.logger.error("Error loading review_project: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      redirect_to admin_review_path, alert: "Error loading project"
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

        if (code_url.start_with?("[") || code_url.start_with?("{")) &&
           (playable_url.start_with?("[") || playable_url.start_with?("{"))
          Rails.logger.warn("Found corrupted project for user #{user.id}: #{project['name']}")
          project["code_url"] = ""
          project["playable_url"] = ""
          modified = true
        elsif code_url.start_with?("[") || code_url.start_with?("{")
          Rails.logger.warn("Cleaning code_url for user #{user.id} project #{project['name']}")
          project["code_url"] = ""
          modified = true
        elsif playable_url.start_with?("[") || playable_url.start_with?("{")
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
