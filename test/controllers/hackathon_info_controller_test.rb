require "test_helper"

class HackathonInfoControllerTest < ActionDispatch::IntegrationTest
  test "hackathon info page loads at main path" do
    get "/hackathon_info"
    assert_response :success
    assert_select "h1", text: /Jackpot Hackathon/
  end

  test "hackathon info page loads under deck" do
    get "/deck/hackathon_info"
    assert_response :success
    assert_select "h1", text: /Jackpot Hackathon/
  end

  test "legacy jackpot paths redirect to main hackathon_info" do
    get "/jackpot/hackathon_info"
    assert_redirected_to "/hackathon_info"
    get "/jackpot/hackathonInfo"
    assert_redirected_to "/hackathon_info"
  end
end
