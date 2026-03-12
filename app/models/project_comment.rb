# frozen_string_literal: true

class ProjectComment < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates :body, presence: true
end

