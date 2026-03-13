class HackatimeHoursSyncJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    service = HackatimeService.new
    start_date = Date.new(2026, 2, 14)

    Project.where.not(hackatime_projects: []).find_each do |project|
      hackatime_id = project.user.slack_id || project.user.hack_club_id
      next unless hackatime_id.present?

      linked = project.hackatime_projects || []
      next if linked.empty?

      total = linked.sum do |hp_name|
        service.get_project_hours(hackatime_id, hp_name, start_date: start_date)
      end

      project.update_column(:hackatime_hours, total) if project.hackatime_hours != total
    rescue => e
      Rails.logger.error("HackatimeHoursSync failed for Project##{project.id}: #{e.message}")
    end
  end
end
