require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "#new" do
    get new_registration_path

    assert_response :success
  end

 test "#create" do
    assert_difference "User.count", 1 do
      post registration_path, params: { user: { email: "test@email.com", password: "password" } }
    end

    assert_redirected_to dashboard_path
  end
end
