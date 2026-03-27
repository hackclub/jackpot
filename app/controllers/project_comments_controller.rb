# frozen_string_literal: true

class ProjectCommentsController < ApplicationController
  before_action :authenticate_user!

  def create
    project = Project.find(params[:project_id])
    unless project.user_id == current_user.id || review_privileged?
      return redirect_to status_path, alert: "You can't comment on that project."
    end

    project.project_comments.create!(
      user: current_user,
      body: params.dig(:project_comment, :body).to_s.strip
    )

    redirect_to status_path
  rescue ActiveRecord::RecordInvalid
    redirect_to status_path, alert: "Comment can't be blank."
  end
end
