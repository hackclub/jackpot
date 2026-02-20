module ApplicationHelper
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
