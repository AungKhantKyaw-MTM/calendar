require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "should get generic_error" do
    get errors_generic_error_url
    assert_response :success
  end
end
