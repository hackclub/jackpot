# frozen_string_literal: true

require "test_helper"

class JackpotHoursTest < ActiveSupport::TestCase
  test "hackatime_hours_from_api_total rounds to 2 decimal places" do
    assert_in_delta 11.5, JackpotHours.hackatime_hours_from_api_total(11.5), 1e-9
    assert_in_delta 12.0, JackpotHours.hackatime_hours_from_api_total(11.999), 1e-9
    assert_in_delta 11.6, JackpotHours.hackatime_hours_from_api_total(11.599), 1e-9
  end

  test "chips_from_approved_hours uses floored whole hours × 50 (always round hours down for chips)" do
    assert_in_delta 550.0, JackpotHours.chips_from_approved_hours(11.5), 1e-9
    assert_in_delta 550.0, JackpotHours.chips_from_approved_hours(11.99), 1e-9
    assert_in_delta 50.0, JackpotHours.chips_from_approved_hours(1.9), 1e-9
    assert_in_delta 250.0, JackpotHours.chips_from_approved_hours(5.5), 1e-9
    assert_in_delta 0.0, JackpotHours.chips_from_approved_hours(0.5), 1e-9
    assert_in_delta 50.0, JackpotHours.chips_from_approved_hours(1.0), 1e-9
  end
end
