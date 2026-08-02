require "test_helper"

class StrategistsControllerTest < ActionDispatch::IntegrationTest
  test "show requires authentication" do
    get strategist_path

    assert_redirected_to new_session_path
  end

  test "create scrapes a website when the token matches the account" do
    user = User.create!(email: "strategist@example.com", password: "password123", strategist_token: "abc123")

    post session_path, params: { session: { email: user.email, password: "password123" } }
    assert_response :redirect
    follow_redirect!

    WebsiteScraper.singleton_class.send(:define_method, :perform) do |**kwargs|
      { title: "Example", summary: "A concise summary.", url: "https://example.com" }
    end

    post strategist_path, params: { url: "https://example.com" }

    assert_redirected_to strategist_path
    assert_equal "Scan completed successfully.", session[:status_message]
    assert_equal "https://example.com", session[:last_scrape_url]
    assert_equal({ title: "Example", summary: "A concise summary.", url: "https://example.com" }, session[:last_scrape_result])
  end

  test "create shows an alert when the scrape fails" do
    user = User.create!(email: "strategist2@example.com", password: "password123", strategist_token: "abc123")

    post session_path, params: { session: { email: user.email, password: "password123" } }
    assert_response :redirect
    follow_redirect!

    WebsiteScraper.singleton_class.send(:define_method, :perform) do |**kwargs|
      raise WebsiteScraper::ScrapeError, "No strategist token found in the website head tag."
    end

    post strategist_path, params: { url: "https://example.com" }

    assert_redirected_to strategist_path
    assert_equal "No strategist token was found. We generated a token for your account (see it below). Add it to the target site head tag and run the scan again.", session[:status_message]
  end

  test "show can render the latest report as text or pdf" do
    user = User.create!(email: "strategist3@example.com", password: "password123")

    post session_path, params: { session: { email: user.email, password: "password123" } }
    assert_response :redirect

    follow_redirect!

    session[:last_analysis_report] = "Go-to-market guide"
    session[:last_scrape_result] = { title: "Example", summary: "A summary", url: "https://example.com" }

    get strategist_path, params: { download: :txt }
    assert_response :success
    assert_equal "text/plain", @response.media_type
    assert_match "Go-to-market guide", @response.body

    get strategist_path, params: { download: :pdf }
    assert_response :success
    assert_equal "application/pdf", @response.media_type
    assert_match "Go-to-market guide", @response.body
    assert_match "BT", @response.body
    assert_match "ET", @response.body
  end
end