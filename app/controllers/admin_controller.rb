class AdminController < ApplicationController
  skip_before_action :check_access_flipper
  before_action :authenticate_admin_area!

  def index
    Rails.logger.info "Current user hack_club_id: #{current_user&.hack_club_id}"
    Rails.logger.info "Is admin? #{admin?}"
    cleanup_corrupted_projects
  end

  def stats
    @total_projects = Project.count
    @pending_projects = Project.where(status: "pending").count
    @in_review_projects = Project.where(status: "in-review").count
    @approved_projects = Project.where(status: "approved").count
    @rejected_projects = Project.where(status: "rejected").count

    @total_logged_hours = Project.sum(:total_hours).to_f
    @approved_hours = Project.where(status: "approved").sum(:approved_hours).to_f
    @pending_review_hours = Project.where(status: "in-review").sum(:total_hours).to_f
    @journal_hours_total = JournalEntry.sum(:hours_worked).to_f
    @journal_entries_count = JournalEntry.count

    @total_bolts_awarded = Project.where(status: "approved").sum(:chips_earned).to_f
    @bolts_in_wallets = User.sum(:chip_am).to_f
    @bolts_spent = @total_bolts_awarded - @bolts_in_wallets

    @total_users = User.count
    @reviewer_users = User.where(role: :reviewer).count
    @full_admin_users = User.where(role: [ :admin, :super_admin ]).count
    @users_with_projects = User.joins(:projects).distinct.count
    @users_with_approved = User.joins(:projects).where(projects: { status: "approved" }).distinct.count

    @total_orders = ShopOrder.count
    @pending_orders = ShopOrder.where(status: "pending").count
    @fulfilled_orders = ShopOrder.where(status: "fulfilled").count
    @total_grant_value = ShopOrder.sum(:price_usd_total_snapshot).to_f

    @orders_by_category = ShopOrder.joins("LEFT JOIN shop_items ON shop_items.id = shop_orders.shop_item_id")
      .group("COALESCE(shop_items.category, 'Uncategorized')")
      .count
      .sort_by { |_, v| -v }

    @top_users_by_hours = User.joins(:projects)
      .where(projects: { status: "approved" })
      .select("users.*, SUM(projects.approved_hours) AS total_approved_hours")
      .group("users.id")
      .order("total_approved_hours DESC")
      .limit(10)

    @top_users_by_bolts = User.where("chip_am > 0").order(chip_am: :desc).limit(10)

    @project_active_users_today = project_active_users_count_for_day(Date.current)
    @daily_project_active_user_series = daily_project_active_user_series(days: 30)
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
      { name: "Shop Item Requests", job_class: "Airtable::ShopItemRequestSyncJob", model: ShopItemRequest, table_env: "AIRTABLE_SHOP_ITEM_REQUESTS_TABLE", table_default: "_shop_item_requests" },
      { name: "YSWS Project Submissions (Shipped)", job_class: "Airtable::ShippedProjectSyncJob", model: YswsProjectSubmission, table_env: "AIRTABLE_SHIPPED_PROJECTS_TABLE", table_default: "YSWS Project Submission", before_stats: -> { YswsProjectSubmission.ensure_rows_for_shipped_projects! } }
    ]

    @sync_jobs.each do |job|
      job[:before_stats]&.call
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
    @airtable_push_pending = SolidQueue::Job.where(class_name: "Airtable::PushRecordJob", finished_at: nil).count

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
    token = Rails.application.credentials&.airtable&.acces_token || ENV["AIRTABLE_API_KEY"]
    base = Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"]
    unless token.present? && base.present?
      redirect_to admin_airtable_sync_path, alert: "Airtable credentials are missing; cannot run sync."
      return
    end

    Airtable::AdminForceSyncJob.perform_later
    redirect_to admin_airtable_sync_path,
      notice: "Full Airtable reconcile is queued (runs in the background). Refresh this page in a minute to see updated counts—ensure bin/jobs (or your Solid Queue worker) is running."
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
       all_db_projects = Project.includes(:user, :ysws_project_submission).order(created_at: :desc)
       pending_db_projects = Project.where(shipped: true, status: "in-review", reviewed: false)
         .includes(:user, :ysws_project_submission).order(created_at: :desc)

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
           "hours" => db_project.total_hours || 0,
           "double_dip" => db_project.double_dip_effective?
         }

         project_item = {
           user: user,
           project: project_hash,
           project_index: db_project.position
         }

         @all_projects << project_item
       end

       pending_db_projects.each do |db_project|
         db_project.ysws_project_submission&.pull_double_dip_from_airtable!
         db_project.reload

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
           "hours" => db_project.total_hours || 0,
           "double_dip" => db_project.double_dip_effective?
         }

         project_item = {
           user: user,
           project: project_hash,
           project_index: db_project.position
         }

         @projects_for_review << project_item
       end

       @ship_sort = %w[asc desc].include?(params[:ship_sort].to_s) ? params[:ship_sort] : "desc"
       sort_review_items_by_shipped_at!(@all_projects, @ship_sort)
       sort_review_items_by_shipped_at!(@projects_for_review, @ship_sort)
     rescue => e
       Rails.logger.error("FATAL ERROR in review action: #{e.class} - #{e.message}")
       Rails.logger.error(e.backtrace.join("\n"))
       @projects_for_review = []
       @all_projects = []
       @ship_sort = "desc"
     end
   end

  def update_review_project_double_dip
    project = Project.find_by(id: params[:project_id])
    unless project
      return head :not_found
    end

    dip = ActiveModel::Type::Boolean.new.cast(params[:double_dip])
    project.update!(double_dip: dip)
    if (sub = project.ysws_project_submission)
      sub.update_column(:double_dip, dip)
      begin
        sub.push_double_dip_to_airtable!
      rescue StandardError => e
        Rails.logger.error("update_review_project_double_dip: Airtable push failed: #{e.class}: #{e.message}")
      end
    end
    head :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
  end

  def review_project
    begin
      project_id = params[:project_id]
      @project_db = Project.includes(:ysws_project_submission).find(project_id)
      @project_db.ysws_project_submission&.pull_double_dip_from_airtable!
      @project_db.reload
      @user = @project_db.user

      unless @user
        redirect_to admin_review_path, alert: "Project user not found"
        return
      end

      # Index aligned with deck / approve endpoints (ordered slots), not raw position column alone
      ordered_ids = @user.projects.order(position: :asc).pluck(:id)
      @project_index = ordered_ids.index(@project_db.id) || @project_db.position

      # Get journal entries
      @journal_entries = @project_db.journal_entries || []
      @all_logged_total_hours = (@project_db.total_hours || 0).to_f
      @hours_beyond_submission = @project_db.hours_logged_beyond_current_queue_submission.to_f
      @banked_hours = @project_db.past_approved_hours.to_f
      @pending_review_hours = @project_db.pending_review_hours

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
        "created_at" => @project_db.created_at&.iso8601,
        "double_dip" => @project_db.double_dip_effective?
      }
    rescue => e
      Rails.logger.error("Error loading review_project: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      redirect_to admin_review_path, alert: "Error loading project"
    end
  end

  def destroy_review_project
    project = Project.find_by(id: params[:project_id])
    unless project
      redirect_to admin_review_path, alert: "Project not found."
      return
    end

    name = project.name
    owner = project.user

    begin
      project.purge_remote_airtable_rows!
    rescue StandardError => e
      # Airtable errors must not block PG delete (otherwise the project stays in Jackpot and the DB).
      Rails.logger.error("destroy_review_project: Airtable purge failed (continuing with PG + legacy JSON cleanup): #{e.class} #{e.message}")
    end

    begin
      owner&.remove_legacy_jsonb_slot_for_project!(project)
    rescue StandardError => e
      Rails.logger.error("destroy_review_project: legacy users.projects jsonb cleanup failed: #{e.class} #{e.message}")
    end

    if project.destroy
      redirect_to admin_review_path, notice: "Project “#{name}” was permanently deleted from PostgreSQL and Airtable."
    else
      redirect_to admin_review_project_path(project_id: project.id),
        alert: "Could not delete project: #{project.errors.full_messages.join(', ')}"
    end
  rescue => e
    Rails.logger.error("destroy_review_project: #{e.class} #{e.message}\n#{e.backtrace&.join("\n")}")
    redirect_to admin_review_path, alert: "Could not delete project."
  end

  private

  # Distinct users with at least one project saved that calendar day (updated_at in app TZ).
  def project_active_users_count_for_day(day)
    Project.where(updated_at: day.in_time_zone.all_day).distinct.count(:user_id)
  end

  def daily_project_active_user_series(days:)
    start_date = (days - 1).days.ago.to_date
    end_date = Date.current
    (start_date..end_date).map do |d|
      [ d, project_active_users_count_for_day(d) ]
    end
  end

  # Unshipped / missing shipped_at sort after shipped rows for both asc and desc.
  def sort_review_items_by_shipped_at!(items, direction)
    dir = direction.to_s == "asc" ? :asc : :desc
    items.sort_by! do |item|
      raw = item.dig(:project, "shipped_at")
      t =
        begin
          Time.zone.parse(raw.to_s) if raw.present?
        rescue ArgumentError, TypeError
          nil
        end
      group = t ? 0 : 1
      key = t ? t.to_f : 0.0
      key = -key if dir == :desc
      [ group, key ]
    end
  end

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

      project_id = project.is_a?(Hash) ? project["id"] : project.id
      Rails.logger.info("        [calculate_project_hours] Getting journal entries for project_id=#{project_id}")
      journal_sum = user.journal_entries.for_project_id(project_id).sum(:hours_worked)
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

  def authenticate_admin_area!
    unless user_signed_in?
      redirect_to "/auth/hackclub", alert: "Please sign in."
      return
    end

    if action_name == "destroy_review_project"
      return if current_user.role_super_admin?

      Rails.logger.warn "Non-super-admin tried destroy_review_project. User: #{current_user.hack_club_id}"
      redirect_to admin_review_path, alert: "Only super-admins can delete projects."
      return
    end

    if %w[stats review review_project update_review_project_double_dip].include?(action_name)
      unless current_user.review_privileged?
        Rails.logger.warn "Non-staff tried to access admin review/stats. User: #{current_user.hack_club_id}"
        redirect_to root_path, alert: "Access denied."
      end
    elsif !current_user.full_admin?
      Rails.logger.warn "Non-admin tried to access admin panel. User: #{current_user&.hack_club_id || 'not logged in'}"
      redirect_to root_path, alert: "Access denied. Admin only."
    end
  end
end
