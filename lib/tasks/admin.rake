namespace :admin do
  desc "Make a user admin by email or Slack ID"
  task :promote, [ :identifier ] => :environment do |t, args|
    identifier = args[:identifier] || ENV["USER_ID"]

    unless identifier
      puts "Usage: bin/rails admin:promote[email_or_slack_id]"
      puts "   Or: USER_ID=email_or_slack_id bin/rails admin:promote"
      exit 1
    end

    user = User.find_by(email: identifier) || User.find_by(hack_club_id: identifier)

    unless user
      puts "User not found with identifier: #{identifier}"
      puts "\nExisting users:"
      User.all.each do |u|
        puts "  - #{u.email} (Slack: #{u.hack_club_id}, Role: #{u.role})"
      end
      exit 1
    end

    user.update!(role: :admin)
    puts "#{user.email} is now an admin!"
    puts "   Slack ID: #{user.hack_club_id}"
    puts "   Full admin check: #{user.full_admin?}"
  end

  desc "List all users with their roles"
  task list: :environment do
    puts "All users:"
    User.all.each do |u|
      admin_marker = u.full_admin? ? "👑" : "  "
      puts "#{admin_marker} #{u.email.ljust(30)} | Slack: #{u.hack_club_id.ljust(15)} | Role: #{u.role}"
    end
  end

  desc "List only staff: reviewers, admins, and super-admins (quick view)"
  task list_staff: :environment do
    reviewers = User.where(role: :reviewer).order(:email)
    admins = User.where(role: :admin).order(:email)
    super_admins = User.where(role: :super_admin).order(:email)

    puts "Reviewers (#{reviewers.count})"
    if reviewers.any?
      reviewers.each { |u| puts "  #{u.email}" }
    else
      puts "  (none)"
    end

    puts "\nAdmins (#{admins.count})"
    if admins.any?
      admins.each { |u| puts "  #{u.email}" }
    else
      puts "  (none)"
    end

    puts "\nSuper-admins (#{super_admins.count})"
    if super_admins.any?
      super_admins.each { |u| puts "  #{u.email}" }
    else
      puts "  (none)"
    end
  end
end
