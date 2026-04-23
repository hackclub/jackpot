class DeckController < ApplicationController
   before_action :authenticate_user!
   before_action :authenticate_review_privileged!, only: [ :approve_project_admin, :reject_project_admin, :comment_review_project_admin ]

  RESHIP_SHIP_SUBMISSION_NOTE_MIN_LENGTH = 40
  SHIP_SUBMISSION_NOTE_REQUIRED_MSG = "Describe what changed since your last ship (Update for reviewers) before shipping.".freeze
  SHIP_SUBMISSION_NOTE_TOO_SHORT_MSG =
    "Your update for reviewers must be at least #{RESHIP_SHIP_SUBMISSION_NOTE_MIN_LENGTH} characters — explain what changed since the last ship.".freeze
  SHIP_CLOSED_SEASON_MSG = "Jackpot is closing the first season - re-opening soon!".freeze

  def index
    projects = current_user.projects.includes(:ysws_project_submission).order(position: :asc).to_a
    project_ids = projects.map(&:id)

    @hackatime_owner_by_name = {}
    projects.each do |p|
      (p.hackatime_projects || []).each do |n|
        k = n.to_s.strip.downcase
        next if k.blank?

        @hackatime_owner_by_name[k] = p.id
      end
    end

    all_journal_entries = project_ids.present? ? current_user.journal_entries.where(project_id: project_ids).to_a : []
    journal_by_project_id = all_journal_entries.group_by(&:project_id)

    service = HackatimeService.new
    start_date = Date.new(2026, 2, 14)
    hackatime_id = current_user.slack_id || current_user.hack_club_id
    Rails.logger.info("DeckController#index: user=#{current_user.id}, slack_id=#{current_user.slack_id}, hack_club_id=#{current_user.hack_club_id}, hackatime_id=#{hackatime_id}")

     @projects = projects.map.with_index do |project, index|
       linked = project.hackatime_projects || []
       hackatime_hours_raw = linked.sum do |hp_name|
         hours = service.get_project_hours(hackatime_id, hp_name, start_date: start_date)
         Rails.logger.info("  project[#{index}] #{hp_name}: #{hours}h from hackatime")
         hours
       end
       hackatime_hours = JackpotHours.hackatime_hours_from_api_total(hackatime_hours_raw)

       if (project.hackatime_hours.to_d - hackatime_hours.to_d).abs > 0.000_05
         project.update_column(:hackatime_hours, hackatime_hours)
       end

       project_journals = journal_by_project_id[project.id] || []
       journal_hours = project_journals.sum(&:hours_worked).to_f
       total_hours = hackatime_hours + journal_hours
       if (project.total_hours.to_d - total_hours.to_d).abs > 0.000_05
         project.update_column(:total_hours, total_hours)
       end
       Rails.logger.info("  project[#{index}]: hackatime=#{hackatime_hours}h + journal=#{journal_hours}h = #{total_hours}h")

       if project.shipped? && project.status.to_s == "in-review" && !project.reviewed? &&
           project.read_attribute(:shipping_queue_snapshot_total_hours).blank?
         project.update_column(:shipping_queue_snapshot_total_hours, total_hours)
         project.reload
       end

       pending_review = project.pending_review_hours
       other_pending_ship = current_user.projects.where.not(id: project.id).where(
         shipped: true,
         status: "in-review",
         reviewed: false
       ).exists?
       project_hash = {
         "id" => project.id,
         "name" => project.name,
         "description" => project.description,
         "project_type" => project.project_type,
        "code_url" => project.code_url,
        "github_username" => project.github_username,
        "playable_url" => project.playable_url,
         "hackatime_projects" => project.hackatime_projects || [],
         "hours" => total_hours,
         "hackatime_hours" => hackatime_hours,
         "journal_hours" => journal_hours,
         "pending_review_hours" => pending_review,
         "unshipped_hours_display" => project.unshipped_hours_for_deck_display.to_f,
         "hours_logged_beyond_queue_submission" => project.hours_logged_beyond_current_queue_submission.to_f,
         "past_approved_hours" => project.past_approved_hours.to_f,
         "first_shipped_at" => project.first_shipped_at&.iso8601,
         "reshippable" => project.reshippable?,
         "user_has_other_pending_ship" => other_pending_ship,
         "main_hc_reship_locked" => project.reship_blocked_by_main_hc_database?,
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
         "created_at" => project.created_at&.iso8601,
         "double_dip" => project.double_dip_effective?
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

    @ship_closed = Rails.application.config.x.ship_closed && !current_user.reship_shipping_enabled?
  end

  def save_project
    project_name = params[:project_name].to_s.strip
    project_description = params[:project_description].to_s.strip
    project_type = params[:project_type].to_s.strip
    playable_url = params[:playable_url].to_s.strip
    code_url = params[:code_url].to_s.strip
    github_username = params[:github_username].to_s.strip.delete_prefix("@")
    banner_url = params[:banner_url].to_s.strip
    hackatime_projects = Array(params[:hackatime_projects]).map(&:strip).reject(&:blank?)
    project_index = params[:project_index].to_i

    will_change_hackatime = true
    if params[:project_index].present? && project_index >= 0
      ex_proj = current_user.projects.order(position: :asc)[project_index]
      will_change_hackatime = false if ex_proj&.first_shipped_at.present? && ex_proj.shipped?
    end

    if will_change_hackatime
      exclude_pid = if params[:project_index].present? && project_index >= 0
                      current_user.projects.order(position: :asc)[project_index]&.id
      else
                      nil
      end
      if (hit = hackatime_first_conflict_with_other_project(current_user, exclude_pid, hackatime_projects))
        msg = "The Hackatime project \"#{hit}\" is already linked to another deck project. Remove it from the other project first."
        if request.xhr?
          return render json: { error: msg }, status: :unprocessable_entity
        else
          flash[:alert] = msg
          return redirect_to deck_path
        end
      end
    end

    if code_url.start_with?("[") || code_url.start_with?("{")
      return render json: { error: "Code URL is invalid" }, status: :unprocessable_entity
    end
    if playable_url.start_with?("[") || playable_url.start_with?("{")
      return render json: { error: "Playable URL is invalid" }, status: :unprocessable_entity
    end

    is_new = false
    project = nil
    projects_count = current_user.projects.count

    if params[:project_index].present? && project_index >= 0
      project = current_user.projects.order(position: :asc)[project_index]
      if project
        base_name = project_name.presence || "Project #{projects_count + 1}"
        if project.first_shipped_at.present? && project.shipped?
          project.update!(
            name: base_name,
            playable_url: playable_url,
            banner_url: banner_url
          )
        else
          project.update!(
            name: base_name,
            description: project_description,
            project_type: project_type,
            playable_url: playable_url,
            code_url: code_url,
            github_username: github_username,
            banner_url: banner_url,
            hackatime_projects: hackatime_projects
          )
        end
      end
    end

    if project.nil?
      project = current_user.projects.create!(
        name: project_name.presence || "Project #{projects_count + 1}",
        description: project_description,
        project_type: project_type,
        playable_url: playable_url,
        code_url: code_url,
        github_username: github_username,
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
    if Rails.application.config.x.ship_closed && !current_user.reship_shipping_enabled?
      if request.xhr?
        return render json: { error: SHIP_CLOSED_SEASON_MSG }, status: :unprocessable_entity
      else
        flash[:alert] = SHIP_CLOSED_SEASON_MSG
        return redirect_to deck_path
      end
    end

    project_index = params[:project_index].to_i
    project = current_user.projects.order(position: :asc)[project_index]
    raw_ship_note = params[:ship_submission_note].to_s.strip
    ship_note = raw_ship_note.presence

    if project
      refresh_logged_totals_for_project!(project, current_user)
      project.reload
      tag_reship_submission = current_user.reship_shipping_enabled? && project.shipped?
      pure_first_ship = !project.shipped? && project.first_shipped_at.blank?

      unless pure_first_ship
        if ship_note.blank?
          if request.xhr?
            return render json: { error: SHIP_SUBMISSION_NOTE_REQUIRED_MSG }, status: :unprocessable_entity
          else
            flash[:alert] = SHIP_SUBMISSION_NOTE_REQUIRED_MSG
            return redirect_to deck_path
          end
        end
        if ship_note.length < RESHIP_SHIP_SUBMISSION_NOTE_MIN_LENGTH
          if request.xhr?
            return render json: { error: SHIP_SUBMISSION_NOTE_TOO_SHORT_MSG }, status: :unprocessable_entity
          else
            flash[:alert] = SHIP_SUBMISSION_NOTE_TOO_SHORT_MSG
            return redirect_to deck_path
          end
        end
      end

      # Pending in queue: Ship update commits new logged time into this submission and moves to the back of the queue.
      if project.shipped? && project.status.to_s == "in-review" && !project.reviewed?
        if project.read_attribute(:shipping_queue_snapshot_total_hours).blank?
          project.update_column(:shipping_queue_snapshot_total_hours, project.total_hours.to_f)
          project.reload
        end
        if project.playable_url.blank? || project.code_url.blank? || project.banner_url.blank? || project.github_username.blank?
          if request.xhr?
            return render json: { error: "Playable URL, Code URL, GitHub username, and Banner image are required to ship" }, status: :unprocessable_entity
          else
            flash[:alert] = "Playable URL, Code URL, GitHub username, and Banner image are required to ship"
            return redirect_to deck_path
          end
        end
        if project.hours_logged_beyond_current_queue_submission <= 1e-6
          msg = "Log more hours on this project, then use Ship update to add them to your pending submission and move it to the back of the queue."
          if request.xhr?
            return render json: { error: msg }, status: :unprocessable_entity
          else
            flash[:alert] = msg
            return redirect_to deck_path
          end
        end
        project.move_to_last_deck_position!
        project.reload
        project.update!(
          shipped: true,
          status: "in-review",
          shipped_at: Time.current,
          shipping_queue_snapshot_total_hours: project.total_hours.to_f,
          hour_justification: ship_note,
          reship_submission: project.reship_submission? || tag_reship_submission
        )
        project.ysws_project_submission&.update_columns(ship_status: "Pending", updated_at: Time.current)

        if request.xhr?
          return render json: { success: true }
        else
          return redirect_to deck_path
        end
      end

      if project.shipped? && project.status.to_s != "rejected"
        if project.reviewed? && project.status.to_s == "approved"
          if !project.reshippable?
            msg = "Log more time (beyond what was already approved) before shipping an update."
            if request.xhr?
              return render json: { error: msg }, status: :unprocessable_entity
            else
              flash[:alert] = msg
              return redirect_to deck_path
            end
          end
        end
      end

      if project.playable_url.blank? || project.code_url.blank? || project.banner_url.blank? || project.github_username.blank?
        if request.xhr?
          return render json: { error: "Playable URL, Code URL, GitHub username, and Banner image are required to ship" }, status: :unprocessable_entity
        else
          flash[:alert] = "Playable URL, Code URL, GitHub username, and Banner image are required to ship"
          return redirect_to deck_path
        end
      end

      reship_from_approved = project.shipped? && project.reviewed? && project.status.to_s == "approved" && project.reshippable?

      if project.status.to_s == "rejected"
        project.clear_stale_ysws_submission_if_any!
        project.displace_conflicting_shipped_same_repo!
      else
        conflict = current_user.projects.shipped.where.not(id: project.id).detect do |p|
          project.ship_queue_conflict?(p) &&
            Project::ACTIVE_SHIP_QUEUE_STATUSES.include?(p.status.to_s)
        end
        if conflict
          msg = "Another project (“#{conflict.name}”) is already in the review queue with the same Hackatime link or GitHub repository. Wait for that review or use a different project."
          if request.xhr?
            return render json: { error: msg }, status: :unprocessable_entity
          else
            flash[:alert] = msg
            return redirect_to deck_path
          end
        end
      end

      project.reload if project.status.to_s == "rejected"

      if reship_from_approved
        project.displace_conflicting_shipped_same_repo!
        project.move_to_last_deck_position!
        project.reload
      end

      now = Time.current
      attrs = {
        shipped: true,
        status: "in-review",
        shipped_at: now,
        first_shipped_at: project.first_shipped_at || now,
        shipping_queue_snapshot_total_hours: project.total_hours.to_f,
        hour_justification: ship_note,
        reship_submission: project.reship_submission? || tag_reship_submission
      }
      if reship_from_approved
        attrs.merge!(
          reviewed: false,
          reviewed_at: nil,
          reviewed_by_user_id: nil,
          approver_display_name: nil,
          approved_hours: nil,
          admin_feedback: nil
        )
      end

      project.update!(attrs)
      project.ysws_project_submission&.update_columns(ship_status: "Pending", updated_at: Time.current)
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

  def unship_project
    project_index = params[:project_index].to_i
    project = current_user.projects.order(position: :asc)[project_index]

    unless project
      if request.xhr?
        return render json: { error: "Project not found" }, status: :unprocessable_entity
      else
        flash[:alert] = "Project not found"
        return redirect_to deck_path
      end
    end

    unless project.withdrawable_from_shipping_queue?
      msg = "Only projects still waiting for review can be removed from the queue. Approved submissions can’t be taken back."
      if request.xhr?
        return render json: { error: msg }, status: :unprocessable_entity
      else
        flash[:alert] = msg
        return redirect_to deck_path
      end
    end

    project.withdraw_from_shipping_queue!
    idx = current_user.projects.order(position: :asc).pluck(:id).index(project.id)
    current_user.unship_project_voluntary_from_queue!(idx) if idx.present?

    if request.xhr?
      render json: { success: true }
    else
      redirect_to deck_path
    end
  rescue ArgumentError => e
    Rails.logger.warn("unship_project: #{e.message}")
    if request.xhr?
      render json: { error: e.message }, status: :unprocessable_entity
    else
      flash[:alert] = e.message
      redirect_to deck_path
    end
  rescue StandardError => e
    Rails.logger.error("Error unshipping project: #{e.message}\n#{e.backtrace.join("\n")}")
    if request.xhr?
      render json: { error: "Could not remove project from the review queue." }, status: :unprocessable_entity
    else
      flash[:alert] = "Could not remove project from the review queue."
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

    project.reload
    refresh_logged_totals_for_project!(project, current_user)
    project.reload
    if project.shipped? && project.status.to_s == "in-review" && !project.reviewed? &&
        project.read_attribute(:shipping_queue_snapshot_total_hours).blank?
      project.update_column(:shipping_queue_snapshot_total_hours, project.total_hours.to_f)
    end
    project.reload

    render json: {
      entry: entry,
      project: deck_project_payload_hash(project, current_user)
    }
  rescue => e
    Rails.logger.error("Error creating journal entry: #{e.message}\n#{e.backtrace.join("\n")}")
    render json: { error: "Error creating journal entry: #{e.message}" }, status: :unprocessable_entity
  end

  def get_journal_entries
    pid = params[:project_id].to_s
    unless pid.match?(/\A\d+\z/) && current_user.projects.exists?(id: pid)
      return render json: []
    end

    entries = current_user.journal_entries.for_project_id(pid).order(created_at: :desc)
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

    uuid = SecureRandom.uuid
    ext = File.extname(file.original_filename).downcase
    content_type = file.content_type.to_s
    body = nil

    # Project banner uploads: resize + JPEG so admin review / deck load smaller assets (journal stays original).
    if ActiveModel::Type::Boolean.new.cast(params[:banner]) &&
        content_type.start_with?("image/") &&
        !content_type.include?("svg")
      begin
        require "image_processing/vips"
        processed = ImageProcessing::Vips
          .source(file)
          .resize_to_limit(1280, 1280)
          .convert("jpeg")
          .saver(quality: 82)
          .call
        body = File.binread(processed.path)
        processed.close!
        content_type = "image/jpeg"
        ext = ".jpg"
      rescue LoadError, StandardError => e
        Rails.logger.warn("upload_image: project banner resize skipped (#{e.class}: #{e.message})")
        file.rewind if file.respond_to?(:rewind)
        body = nil
      end
    end

    body ||= file.read
    key = "journal-images/#{current_user.id}/#{uuid}#{ext}"

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
      body: body,
      content_type: content_type,
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
    project_id = params[:project_id]
    approved_hours = params[:approved_hours].to_f
    justification = params[:hour_justification].to_s.strip
    feedback = params[:feedback]

    user = User.find(user_id)
    new_hours = approved_hours.to_f

    # Resolve project by id (status page sync) or by index
    project = if project_id.present?
                user.projects.find_by(id: project_id)
    else
                user.projects.order(position: :asc)[project_index]
    end

    unless project
      Rails.logger.error "Project not found for user #{user_id} (project_id=#{project_id}, project_index=#{project_index})"
      return render json: { error: "Project not found" }, status: :unprocessable_entity
    end

    unless project.shipped?
      return render json: { error: "Project is not in the review queue" }, status: :unprocessable_entity
    end

    pending_cap = project.pending_review_hours
    if new_hours <= 0
      return render json: { error: "Enter a positive number of new hours to approve for this submission." }, status: :unprocessable_entity
    end
    if new_hours > pending_cap + 0.02
      return render json: { error: "Cannot approve more new hours than the participant has logged beyond prior approvals (#{pending_cap.round(2)} h max)." }, status: :unprocessable_entity
    end

    floor = project.past_approved_hours.to_f
    new_total = (floor + new_hours).round(2)
    chips_delta = JackpotHours.chips_from_approved_hours(new_hours)
    new_cumulative_chips = (project.chips_earned.to_f + chips_delta).round(2)

    # Derive index from project position for User#approve_project (chip_am / legacy jsonb)
    resolved_index = user.projects.order(position: :asc).pluck(:id).index(project.id)

    Rails.logger.info "Approving project for user #{user_id} project_id=#{project.id}: +#{new_hours} h (total #{new_total}) = +#{chips_delta} chips"

    begin
      submitter_update_comment = project.hour_justification.to_s.strip
      merged_justification = justification.presence || project.hour_justification

      # Always update the Project record so status page shows review (single source of truth)
      project.update!(
        reviewed: true,
        reviewed_at: Time.current,
        status: "approved",
        approved_hours: new_total,
        past_approved_hours: new_total,
        hour_justification: merged_justification,
        admin_feedback: feedback,
        chips_earned: new_cumulative_chips,
        reviewed_by_user_id: current_user.id,
        approver_display_name: current_user.jackpot_profile_name
      )

      user.approve_project(resolved_index, new_total, merged_justification, feedback, new_chip_award: chips_delta) if resolved_index.present?

      submission = YswsProjectSubmission.ensure_row_for_project!(project.reload)
      if submission && floor > 0
        entry = YswsProjectSubmission.build_update_desc_entry(
          past_approved_hours: floor,
          user_comment: submitter_update_comment,
          new_hours: new_hours
        )
        combined = [ submission.update_desc_log.to_s.strip, entry ].reject(&:blank?).join("\n\n")
        submission.update!(update_desc_log: combined)
      end

      submission&.rebuild_and_push_optional_override_justification!

      Rails.logger.info "Project approved. User #{user_id} earned #{chips_delta} chips (delta). New balance: #{user.reload.chip_am}"
      render json: { success: true, message: "Project approved", chips_earned: chips_delta }
    rescue => e
      Rails.logger.error "Error approving project: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def reject_project_admin
    user_id = params[:user_id]
    project_index = params[:project_index].to_i
    project_id = params[:project_id]
    feedback = params[:feedback]

    user = User.find(user_id)

    # Resolve project by id (status page sync) or by index
    project = if project_id.present?
                user.projects.find_by(id: project_id)
    else
                user.projects.order(position: :asc)[project_index]
    end

    unless project
      Rails.logger.error "Project not found for user #{user_id} (project_id=#{project_id}, project_index=#{project_index})"
      return render json: { error: "Project not found" }, status: :unprocessable_entity
    end

    unless project.shipped?
      return render json: { error: "Project is not in the review queue" }, status: :unprocessable_entity
    end

    feedback_text = feedback.to_s.strip
    if feedback_text.blank?
      return render json: { error: "Rejection requires a written comment (what to fix before resubmitting)." }, status: :unprocessable_entity
    end

    resolved_index = user.projects.order(position: :asc).pluck(:id).index(project.id)

    Rails.logger.info "Rejecting project for user #{user_id} project_id=#{project.id}"

    begin
      banked_hours = project.past_approved_hours.to_f
      # Return project to the deck (not shipped) and drop the YSWS submission row; clear approval fields; keep feedback.
      project.unship_return_to_deck_after_rejection!(admin_feedback: feedback_text)
      if resolved_index.present?
        user.unship_project_after_rejection!(
          resolved_index,
          admin_feedback: feedback_text,
          restore_approved_hours: (banked_hours.positive? ? banked_hours : nil)
        )
      end

      project.reload
      project.project_comments.create!(user: current_user, body: "Rejected — #{feedback_text}")

      Rails.logger.info "Project rejected for user #{user_id}"
      render json: { success: true, message: "Project rejected" }
    rescue => e
      Rails.logger.error "Error rejecting project: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  # Admin-only: leave a note on a shipped project without changing approval state (still in review queue).
  def comment_review_project_admin
    user_id = params[:user_id]
    project_index = params[:project_index].to_i
    project_id = params[:project_id]
    body = params[:feedback].to_s.strip

    if body.blank?
      return render json: { error: "Comment can’t be blank." }, status: :unprocessable_entity
    end

    user = User.find(user_id)
    project = if project_id.present?
                user.projects.find_by(id: project_id)
    else
                user.projects.order(position: :asc)[project_index]
    end

    unless project
      return render json: { error: "Project not found" }, status: :unprocessable_entity
    end
    unless project.shipped?
      return render json: { error: "Comment-only review applies to projects still in the shipped review queue." }, status: :unprocessable_entity
    end

    project.project_comments.create!(user: current_user, body: body)
    render json: { success: true, message: "Comment posted" }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "User or project not found" }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Error posting review comment: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  # Single-project deck stats (matches DeckController#index math) for JSON responses after journal saves.
  def deck_project_payload_hash(project, user)
    hackatime_hours = project.hackatime_hours.to_f
    journal_hours = JournalEntry.where(user_id: user.id, project_id: project.id).sum(:hours_worked).to_f
    total_hours = hackatime_hours + journal_hours
    other_pending_ship = user.projects.where.not(id: project.id).where(
      shipped: true,
      status: "in-review",
      reviewed: false
    ).exists?

    {
      "id" => project.id,
      "hours" => total_hours,
      "hackatime_hours" => hackatime_hours,
      "journal_hours" => journal_hours,
      "pending_review_hours" => project.pending_review_hours,
      "unshipped_hours_display" => project.unshipped_hours_for_deck_display.to_f,
      "hours_logged_beyond_queue_submission" => project.hours_logged_beyond_current_queue_submission.to_f,
      "reshippable" => project.reshippable?,
      "user_has_other_pending_ship" => other_pending_ship,
      "main_hc_reship_locked" => project.reship_blocked_by_main_hc_database?
    }
  end

  def refresh_logged_totals_for_project!(project, user)
    service = HackatimeService.new
    start_date = Date.new(2026, 2, 14)
    hackatime_id = user.slack_id || user.hack_club_id
    linked = project.hackatime_projects || []
    hackatime_hours_raw = linked.sum do |hp_name|
      (service.get_project_hours(hackatime_id, hp_name, start_date: start_date) || 0).to_f
    end
    hackatime_hours = JackpotHours.hackatime_hours_from_api_total(hackatime_hours_raw)
    if (project.hackatime_hours.to_d - hackatime_hours.to_d).abs > 0.000_05
      project.update_column(:hackatime_hours, hackatime_hours)
    end

    journal_hours = JournalEntry.where(user_id: user.id, project_id: project.id).sum(:hours_worked).to_f
    total = hackatime_hours + journal_hours
    if (project.total_hours.to_d - total.to_d).abs > 0.000_05
      project.update_column(:total_hours, total)
    end
  end

  def hackatime_first_conflict_with_other_project(user, exclude_project_id, names)
    norm = Array(names).map { |s| s.to_s.strip.downcase }.reject(&:blank?)
    return nil if norm.empty?

    scope = user.projects
    scope = scope.where.not(id: exclude_project_id) if exclude_project_id.present?

    scope.find_each do |other|
      other_set = (other.hackatime_projects || []).map { |s| s.to_s.strip.downcase }.reject(&:blank?)
      hit = (norm & other_set).first
      return hit if hit
    end
    nil
  end

  def authenticate_review_privileged!
    redirect_to root_path, alert: "Access denied." unless review_privileged?
  end
end
