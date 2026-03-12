class Airtable::ProjectCommentSyncJob < Airtable::BaseSyncJob
  def table_name
    ENV.fetch("AIRTABLE_PROJECT_COMMENTS_TABLE", "_project_comment")
  end

  def records
    ProjectComment.all
  end

  def field_mapping(comment)
    {
      "Body" => comment.body,
      "Created At" => comment.created_at&.iso8601
    }
  end
end
