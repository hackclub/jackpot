# frozen_string_literal: true

# Hackatime totals from the API are floats; we round for decimal columns and compare with a small
# epsilon so float noise does not cause endless update_column churn.
module JackpotHours
  HACKATIME_HOURS_EPSILON = BigDecimal("0.00005")

  module_function

  def hackatime_hours_from_api_total(raw)
    return BigDecimal("0") if raw.nil?

    BigDecimal(raw.to_s).round(2)
  end

  def hackatime_hours_differ?(stored, computed)
    s = stored.nil? ? BigDecimal("0") : BigDecimal(stored.to_s)
    c = computed.nil? ? BigDecimal("0") : BigDecimal(computed.to_s)
    (s - c).abs > HACKATIME_HOURS_EPSILON
  end
end
