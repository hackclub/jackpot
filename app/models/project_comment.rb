# frozen_string_literal: true

class ProjectComment < ApplicationRecord
  include AirtablePushOnChange
  include AirtableSyncedRowDeletion

  belongs_to :project
  belongs_to :user

  validates :body, presence: true

  pushes_airtable_with Airtable::ProjectCommentSyncJob

  def self.airtable_sync_table_name
    ENV.fetch("AIRTABLE_PROJECT_COMMENTS_TABLE", "_project_comment")
  end
end
