class Airtable::ShopOrderSyncJob < Airtable::BaseSyncJob
  def table_name
    ENV.fetch("AIRTABLE_SHOP_ORDERS_TABLE", "_shop_orders")
  end

  def records
    ShopOrder.all
  end

  def field_mapping(order)
    {
      "Item Name" => order.item_name,
      "Price" => order.price.to_f,
      "Quantity" => order.quantity,
      "Status" => order.status,
      "User Email" => order.user_email,
      "Slack ID" => order.slack_id,
      "Created At" => order.created_at&.iso8601
    }
  end
end
