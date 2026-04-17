class Airtable::ShopItemSyncJob < Airtable::BaseSyncJob
  def table_name
    ENV.fetch("AIRTABLE_SHOP_ITEMS_TABLE", "_shop_item")
  end

  def records
    ShopItem.all
  end

  def field_mapping(item, is_new_airtable_record: false)
    {
      "Name" => item.name,
      "Description" => item.description,
      "Price" => item.price.to_f,
      "Price USD" => item.price_usd.to_f,
      "Dollar Per Hour" => item.dollar_per_hour.to_f,
      "Category" => item.category,
      "Grant Type" => item.grant_type,
      "Active" => item.active,
      "Item Quantity" => item.item_quantity,
      "Max Per Person" => item.max_per_person,
      "id" => item.id.to_s,
      "Created At" => item.created_at&.iso8601
    }
  end
end
