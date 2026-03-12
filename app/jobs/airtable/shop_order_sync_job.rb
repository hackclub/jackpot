class Airtable::ShopOrderSyncJob < Airtable::BaseSyncJob
  def table_name
    ENV.fetch("AIRTABLE_SHOP_ORDERS_TABLE", "_shop_order")
  end

  def records
    ShopOrder.all
  end

  def field_mapping(order)
    {
      "item_name" => order.item_name,
      "price" => order.price.to_f,
      "quantity" => order.quantity,
      "status" => order.status,
      "user_email" => order.user_email,
      "slack_id" => order.slack_id,
      "id" => order.id.to_s,
      "created_at" => order.created_at&.iso8601
    }
  end
end
