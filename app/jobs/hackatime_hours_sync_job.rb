class HackatimeHoursSyncJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    service = HackatimeService.new
    start_date = Date.new(2026, 2, 14)

    User.includes(:projects).find_each do |user|
      hackatime_id = user.slack_id || user.hack_club_id
      next unless hackatime_id.present?

      user_total = 0.0

      user.projects.each do |project|
        linked = project.hackatime_projects || []
        project_total =
          if linked.empty?
            0
          else
            project_total_raw = linked.sum do |hp_name|
              service.get_project_hours(hackatime_id, hp_name, start_date: start_date)
            end
            JackpotHours.hackatime_hours_from_api_total(project_total_raw)
          end

        if (project.hackatime_hours.to_d - project_total.to_d).abs > 0.000_05
          project.update_column(:hackatime_hours, project_total)
          Airtable::PushRecordJob.enqueue_if_configured(Airtable::ProjectSyncJob, project.id)
        end
        user_total += project_total
      rescue => e
        Rails.logger.error("HackatimeHoursSync failed for Project##{project.id}: #{e.message}")
      end

      if user.hackatime_hours != user_total
        user.update_column(:hackatime_hours, user_total)
        Airtable::PushRecordJob.enqueue_if_configured(Airtable::UserSyncJob, user.id)
      end
    rescue => e
      Rails.logger.error("HackatimeHoursSync failed for User##{user.id}: #{e.message}")
    end
  end
end
