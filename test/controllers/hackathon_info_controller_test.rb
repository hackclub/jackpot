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

  test "includes current confirmed participants bar and label" do
    get "/hackathon_info"
    assert_response :success
    assert_select ".hackathon-participants-counter-bare"
    assert_select ".hackathon-signup-progress--confirmed .hackathon-signup-label",
      text: "Current confirmed participants"
    assert_select ".hackathon-participants-quick-questions", text: /For any quick questions, DM/
    assert_select ".hackathon-participants-quick-questions a[href='https://hackclub.enterprise.slack.com/team/U078DFX40A2']",
      text: "@Emma"
  end
end
