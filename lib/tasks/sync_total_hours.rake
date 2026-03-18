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
end
