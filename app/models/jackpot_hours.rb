# frozen_string_literal: true

# Hackatime API returns fractional hours; we never round up to the next whole hour for display/totals.
# Chip awards (1 hr = 50 chips) never round up: chip delta uses floor at cent precision.
module JackpotHours
  module_function

  # Truncate toward -infinity to 2 decimal places (e.g. 11.999 -> 11.99, not 12.0).
  def hackatime_hours_from_api_total(raw_hours)
    BigDecimal(raw_hours.to_s).floor(2).to_f
  end

  def chips_from_approved_hours(hours)
    (BigDecimal(hours.to_s) * 50).floor(2).to_f
  end
end
