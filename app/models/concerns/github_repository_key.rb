# frozen_string_literal: true

# Normalizes a GitHub repo from a code URL to "owner/repo" (lowercase) for deduplication.
module GithubRepositoryKey
  extend ActiveSupport::Concern

  class_methods do
    def github_repository_key(url)
      s = url.to_s.strip
      return nil if s.blank?

      if (m = s.match(%r{\Agit@github\.com:([^/\s?#]+/[^/\s?#]+)}i))
        return normalize_repo_segment(m[1])
      end

      return nil unless s.match?(/github\.com/i)

      m = s.match(%r{github\.com[/:]([^/\s?#]+)/([^/\s?#]+)}i)
      return nil unless m

      normalize_repo_segment("#{m[1]}/#{m[2]}")
    end

    def normalize_repo_segment(segment)
      seg = segment.to_s.sub(%r{\.git\z}i, "").strip
      return nil if seg.blank?

      owner, repo = seg.split("/", 2)
      return nil if owner.blank? || repo.blank?
      return nil if %w[orgs settings topics features enterprise].include?(owner.downcase)

      "#{owner}/#{repo}".downcase
    end
  end
end
