class Airtable::ShopOrderSyncJob < Airtable::BaseSyncJob
  def table_name
    ENV.fetch("AIRTABLE_SHOP_ORDERS_TABLE", "_shop_order")
  end

  def records
    ShopOrder.all
  end

  def field_mapping(order, is_new_airtable_record: false)
    fields = {
      "item_name" => order.item_name,
      "price" => order.price.to_f,
      "quantity" => order.quantity,
      "status" => order.status,
      "user_email" => order.user_email,
      "slack_id" => order.slack_id,
      "id" => order.id.to_s,
      "created_at" => order.created_at&.iso8601
    }
    if (usd_field = ENV["AIRTABLE_SHOP_ORDER_USD_TOTAL_SNAPSHOT_FIELD"].presence) && order.price_usd_total_snapshot.present?
      fields[usd_field] = order.price_usd_total_snapshot.to_f
    end
    if (f = ENV["AIRTABLE_SHOP_ORDER_USD_ITEMS_SNAPSHOT_FIELD"].presence) && order.price_usd_items_snapshot.present?
      fields[f] = order.price_usd_items_snapshot.to_f
    end
    if (f = ENV["AIRTABLE_SHOP_ORDER_USD_SHIPPING_SNAPSHOT_FIELD"].presence) && order.price_usd_shipping_snapshot.present?
      fields[f] = order.price_usd_shipping_snapshot.to_f
    end
    if (f = ENV["AIRTABLE_SHOP_ORDER_AMOUNT_DESCRIPTION_FIELD"].presence)
      desc = order.usd_amount_description
      fields[f] = desc if desc.present?
    end
    fields
  end
end
