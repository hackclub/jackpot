class DeckController < ApplicationController
  before_action :authenticate_user!

  def index
    @projects = current_user.projects || []
    @show_tutorial = !current_user.tutorial_completed?
  end

  def add_project
    projects = current_user.projects || []
    project_number = projects.size + 1
    projects << { "name" => "Project #{project_number}", "created_at" => Time.current.iso8601 }
    current_user.update!(projects: projects)
    redirect_to deck_path
  end

  def complete_tutorial
    current_user.update!(tutorial_completed: true)
    head :ok
  end
end
