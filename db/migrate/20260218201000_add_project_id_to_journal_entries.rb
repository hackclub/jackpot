class AddProjectIdToJournalEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :journal_entries, :project_id, :bigint unless column_exists?(:journal_entries, :project_id)
    add_foreign_key :journal_entries, :projects, if_not_exists: true
  end
end
