# frozen_string_literal: true

require "set"

module AdminShop
  # Aggregated pending line for admin fulfillment (merges multiple pending rows for same user + item).
  module VirtualOrderCards
    Card = Struct.new(
      :order_ids,
      :user,
      :item_name,
      :shop_item_id,
      :quantity,
      :chip_total,
      :usd_items,
      :usd_shipping,
      :usd_total,
      :already_repeat,
      :earliest_at,
      keyword_init: true
    )

    module_function

    def item_key_for(order)
      if order.shop_item_id.present?
        "id:#{order.shop_item_id}"
      else
        "name:#{order.item_name.to_s.strip.downcase}"
      end
    end

    def sent_keys_by_user
      h = Hash.new { |hh, k| hh[k] = Set.new }
      ShopOrder.where(status: "sent").find_each do |o|
        h[o.user_id] << item_key_for(o)
      end
      h
    end

    def pending_cards
      orders = ShopOrder.where(status: "pending").includes(:user, :shop_item).order(:created_at).to_a
      sent = sent_keys_by_user
      groups = orders.group_by { |o| [ o.user_id, item_key_for(o) ] }

      groups.map do |_gkey, group|
        first = group.min_by(&:created_at)
        uid = first.user_id
        k = item_key_for(first)
        Card.new(
          order_ids: group.map(&:id).sort,
          user: first.user,
          item_name: first.item_name,
          shop_item_id: first.shop_item_id,
          quantity: group.sum(&:quantity),
          chip_total: group.sum { |o| o.price.to_d },
          usd_items: group.sum { |o| (o.price_usd_items_snapshot.presence || o.price_usd_total_snapshot || 0).to_d },
          usd_shipping: group.sum { |o| (o.price_usd_shipping_snapshot || 0).to_d },
          usd_total: group.sum { |o| (o.price_usd_total_snapshot || 0).to_d },
          already_repeat: sent[uid].include?(k),
          earliest_at: group.map(&:created_at).min
        )
      end.sort_by { |c| -c.earliest_at.to_i }
    end

    def group_cards_by_item(cards)
      cards.group_by do |c|
        c.shop_item_id.present? ? "id:#{c.shop_item_id}" : "name:#{c.item_name.to_s.strip.downcase}"
      end
    end

    def group_cards_by_user(cards)
      cards.group_by { |c| c.user&.id.to_i }
    end
  end
end
