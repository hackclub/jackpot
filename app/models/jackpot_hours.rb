# frozen_string_literal: true

# Hackatime API returns fractional hours; store/display to 2 decimal places (half-up), not truncated down.
# Chips: only whole hours count toward the 1h = 50 chips rate — hours are floored before conversion,
# then chips are rounded to 2 decimal places (e.g. 1.9h → 1h → 50 chips; 5.5h → 5h → 250 chips).
module JackpotHours
  module_function

  def hackatime_hours_from_api_total(raw_hours)
    BigDecimal(raw_hours.to_s).round(2).to_f
  end

  def chips_from_approved_hours(hours)
    floored_whole_hours = BigDecimal(hours.to_s).floor(0)
    (floored_whole_hours * 50).round(2).to_f
  end
end
