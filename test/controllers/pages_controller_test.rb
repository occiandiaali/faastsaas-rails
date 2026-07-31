require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "#home is accessible by anyone" do
    get root_path

    assert_response :success
  end
end
