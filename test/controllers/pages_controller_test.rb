require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "Startseite ist erreichbar" do
    get root_path

    assert_response :success
    assert_select "h1", "Probiert"
  end
end
