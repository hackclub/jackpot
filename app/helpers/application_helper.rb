module ApplicationHelper
  # Home for staff navigation (reviewer hub vs full admin panel).
  def staff_home_path
    return admin_path unless user_signed_in?

    current_user.full_admin? ? admin_path : reviewer_path
  end

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

  # Chips charged at checkout (includes item line + optional shipping/tax chips).
  def shop_order_chips_and_usd(order)
    chips = number_with_precision(order.price.to_f, precision: 0, strip_insignificant_zeros: true)
    "#{chips} chips"
  end

  # Aggregated pending card (merged pending rows for same user + catalog item).
  def admin_shop_virtual_card_price_line(card)
    total_chips = number_with_precision(card.chip_total.to_f, precision: 0, strip_insignificant_zeros: true)
    "Qty: #{card.quantity} · Total: #{total_chips} chips"
  end

  # USD grant breakdown at purchase (admin virtual card).
  def admin_shop_virtual_card_usd_block(card)
    total = card.usd_total.to_f
    return "".html_safe unless total.positive?

    items = card.usd_items.to_f
    ship = card.usd_shipping.to_f
    fmt = ->(x) { number_with_precision(x, precision: 2) }
    content_tag(:div, class: "asoc-usd-desc") do
      safe_join([
        content_tag(:div, "Total: $#{fmt.call(total)}"),
        content_tag(:div, "Items-only: $#{fmt.call(items)}"),
        content_tag(:div, "Shipping: $#{fmt.call(ship)}")
      ])
    end
  end

  # Plain-text USD breakdown for a single order (e.g. tooltips); see also #shop_order_usd_breakdown_html.
  def shop_order_usd_amount_description(order)
    order.usd_amount_description
  end

  def shop_order_usd_breakdown_html(order)
    desc = order.usd_amount_description
    return "".html_safe if desc.blank?

    content_tag(:div, class: "shop-order-usd-breakdown") do
      safe_join(
        desc.split("\n").map { |line| content_tag(:div, line.strip, class: "shop-order-usd-breakdown__line") }
      )
    end
  end
end
