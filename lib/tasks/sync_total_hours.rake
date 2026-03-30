namespace :projects do
  desc "Fetch Hackatime from API into projects/users, then set total_hours = hackatime + journal on every project. Safe: update_column only, no deletes."
  task resync_hackatime_and_totals: :environment do
    puts "Step 1/2: HackatimeHoursSyncJob (API → projects.hackatime_hours, users.hackatime_hours)..."
    HackatimeHoursSyncJob.perform_now
    puts "Step 2/2: total_hours = hackatime_hours + journal hours per project..."
    Rake::Task["projects:sync_total_hours"].invoke
  end

  desc "Sync total_hours for all projects"
  task sync_total_hours: :environment do
    no_hackatime_link = 0
    with_hackatime_link = 0

    Project.find_each do |project|
      journal_hours = JournalEntry.where(project_id: project.id).sum(:hours_worked).to_f || 0
      hackatime_hours = project.hackatime_hours.to_f || 0
      total = journal_hours + hackatime_hours

      linked = Array(project.hackatime_projects).map { |s| s.to_s.strip }.reject(&:blank?)
      if linked.empty?
        no_hackatime_link += 1
      else
        with_hackatime_link += 1
      end

      project.update_column(:total_hours, total)
      ht = hackatime_hours.round(2)
      jh = journal_hours.round(2)
      tt = total.round(2)
      puts "✓ #{project.user.email} - #{project.name}: #{ht}h (hackatime) + #{jh}h (journal) = #{tt}h"
    end
    puts "\nTotal hours synced for all projects"
    puts "Note: #{no_hackatime_link} projects have no Hackatime project names linked (hackatime stays 0 until linked in the deck)."
    puts "      #{with_hackatime_link} projects have at least one linked Hackatime name."
  end
end
