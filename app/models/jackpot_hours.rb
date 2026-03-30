# frozen_string_literal: true

# Hackatime API returns fractional hours; store/display to 2 decimal places (half-up), not truncated down.
# Chips: 1 hr = 50 chips, rounded to 2 decimal places (same as historical Jackpot behavior).
module JackpotHours
  module_function

  def hackatime_hours_from_api_total(raw_hours)
    BigDecimal(raw_hours.to_s).round(2).to_f
  end

  def chips_from_approved_hours(hours)
    (BigDecimal(hours.to_s) * 50).round(2).to_f
  end
end
