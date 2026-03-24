# frozen_string_literal: true

class ProjectComment < ApplicationRecord
  include AirtablePushOnChange

  belongs_to :project
  belongs_to :user

  validates :body, presence: true

  pushes_airtable_with Airtable::ProjectCommentSyncJob
end
