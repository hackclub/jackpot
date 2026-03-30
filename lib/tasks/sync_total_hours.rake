namespace :projects do
  desc "Sync total_hours for all projects"
  task sync_total_hours: :environment do
    Project.find_each do |project|
      journal_hours = JournalEntry.where(project_id: project.id).sum(:hours_worked).to_f || 0
      hackatime_hours = project.hackatime_hours.to_f || 0
      total = journal_hours + hackatime_hours

      project.update_column(:total_hours, total)
      puts "✓ #{project.user.email} - #{project.name}: #{hackatime_hours}h (hackatime) + #{journal_hours}h (journal) = #{total}h"
    end
    puts "\nTotal hours synced for all projects"
  end

  desc "Refresh Hackatime from API for all users, then total_hours = hackatime + journal on every project. " \
       "Updates columns only (no deletes). May enqueue Airtable syncs when values change. " \
       "Run once after deploy: bin/rails projects:refresh_all_logged_hours"
  task refresh_all_logged_hours: :environment do
    puts "Step 1/2: HackatimeHoursSyncJob (fetch Hackatime, update project + user hackatime columns)..."
    HackatimeHoursSyncJob.perform_now
    puts "Step 2/2: Recompute total_hours (hackatime + journal) for each project..."
    updated_totals = 0
    Project.find_each do |project|
      journal_hours = JournalEntry.where(project_id: project.id).sum(:hours_worked).to_f
      hackatime_hours = project.hackatime_hours.to_f
      total = journal_hours + hackatime_hours
      next if (project.total_hours.to_d - total.to_d).abs <= 0.000_05

      project.update_column(:total_hours, total)
      updated_totals += 1
      if ENV["VERBOSE"].present?
        puts "  total_hours → #{total} (#{hackatime_hours}h hackatime + #{journal_hours}h journal) — #{project.user.email} / #{project.name} (id=#{project.id})"
      end
    end
    puts "Done. Updated total_hours on #{updated_totals} project(s) (all projects scanned)."
  end
end
