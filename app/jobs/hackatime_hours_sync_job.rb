class HackatimeHoursSyncJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    service = HackatimeService.new
    start_date = Date.new(2026, 2, 14)

    User.includes(:projects).find_each do |user|
      hackatime_id = user.slack_id || user.hack_club_id
      next unless hackatime_id.present?

      user_total = 0.0
      hours_map = service.hours_by_project_name(hackatime_id, start_date: start_date)

      user.projects.each do |project|
        linked = project.hackatime_projects || []
        project_total =
          if linked.empty?
            0.0
          else
            linked.sum do |hp_name|
              key = hp_name.to_s.strip.downcase
              hours_map[key].to_f
            end.round(2)
          end

        if project.hackatime_hours.to_f.round(2) != project_total.to_f.round(2)
          project.update_column(:hackatime_hours, project_total)
          Airtable::PushRecordJob.enqueue_if_configured(Airtable::ProjectSyncJob, project.id)
        end
        user_total += project_total
      rescue => e
        Rails.logger.error("HackatimeHoursSync failed for Project##{project.id}: #{e.message}")
      end

      if user.hackatime_hours.to_f.round(2) != user_total.to_f.round(2)
        user.update_column(:hackatime_hours, user_total)
        Airtable::PushRecordJob.enqueue_if_configured(Airtable::UserSyncJob, user.id)
      end
    rescue => e
      Rails.logger.error("HackatimeHoursSync failed for User##{user.id}: #{e.message}")
    end
  end
end
