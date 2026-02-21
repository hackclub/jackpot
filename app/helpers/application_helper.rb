module ApplicationHelper
  # Returns per-request cache hit/miss counts from thread-local storage
  def cache_stats
    hits = Thread.current[:cache_hits] || 0
    misses = Thread.current[:cache_misses] || 0
    { hits: hits, misses: misses }
  end

  # Returns per-request DB query counts from thread-local storage
  def db_stats
    queries = Thread.current[:db_query_count] || 0
    cached = Thread.current[:db_cached_count] || 0
    { queries: queries, cached: cached }
  end

  # Returns a hash with signed-in user count and visitor count (last 15 minutes)
  def active_user_stats
    signed_in = User.where("last_sign_in_at > ?", 15.minutes.ago).count
    # Visitors are approximated as users who signed in within the last day but not last 15 min
    visitors = User.where(last_sign_in_at: 1.day.ago..15.minutes.ago).count
    { signed_in: signed_in, visitors: visitors }
  end

  def render_journal_description(text)
    return "".html_safe if text.blank?

    result    = +""
    remainder = text.to_s
    pattern   = /!\[([^\]]*)\]\(([^)]+)\)/

    while (m = pattern.match(remainder))
      result << ERB::Util.html_escape(m.pre_match)

      alt = m[1]
      url = m[2]

      if url.match?(/\Ahttps?:\/\//i)
        result << "<img src=\"#{ERB::Util.html_escape(url)}\" alt=\"#{ERB::Util.html_escape(alt)}\" style=\"max-width:100%;border-radius:6px;margin:6px 0;display:block;\">"
      else
        result << ERB::Util.html_escape(m[0])
      end

      remainder = m.post_match
    end

    result << ERB::Util.html_escape(remainder)
    result.html_safe
  end
end
