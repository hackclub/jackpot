class Airtable::ShopItemRequestSyncJob < Airtable::BaseSyncJob
  def table_name
    ENV.fetch("AIRTABLE_SHOP_ITEM_REQUESTS_TABLE", "_shop_item_request")
  end

  def records
    ShopItemRequest.all
  end

  def field_mapping(request)
    {
      "Item Name" => request.item_name,
      "Price" => request.price.to_f,
      "id" => request.id.to_s,
      "Reference Link" => request.reference_link,
      "Approved" => request.approved,
      "Created At" => request.created_at&.iso8601
    }
  end
end
