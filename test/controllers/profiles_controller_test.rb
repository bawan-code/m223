require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "Gast wird zur Anmeldung geleitet" do
    get profile_path

    assert_redirected_to new_session_path
  end

  test "Profil zeigt Name, E-Mail und Rolle des angemeldeten Benutzers" do
    sign_in_as users(:moni)

    get profile_path

    assert_response :success
    assert_select ".card", text: /Moni Steiner/
    assert_select ".card", text: /moni@example.test/
    assert_select ".card", text: /Moderator/
  end

  test "es gibt keine Route auf ein fremdes Profil" do
    sign_in_as users(:anna)

    assert_raises ActionController::RoutingError do
      Rails.application.routes.recognize_path("/profiles/#{users(:ben).id}")
    end

    get "/profiles/#{users(:ben).id}"
    assert_response :not_found
  end

  test "das Bearbeitungsformular zeigt den aktuellen Namen" do
    sign_in_as users(:anna)

    get edit_profile_path

    assert_response :success
    assert_select "input[name='user[name]'][value=?]", "Anna Keller"
    assert_select "form[action=?]", profile_path do
      assert_select "input[name=_method][value=patch]"
    end
  end

  test "Name ändern" do
    sign_in_as users(:anna)

    patch profile_path, params: { user: { name: "Anna Keller-Meier" } }

    assert_redirected_to profile_path
    assert_equal "Anna Keller-Meier", users(:anna).reload.name
  end

  test "leerer Name wird abgelehnt, Eingabe bleibt stehen" do
    sign_in_as users(:anna)

    patch profile_path, params: { user: { name: "  " } }

    assert_response :unprocessable_entity
    assert_select ".errors li", text: /Name muss ausgefüllt werden/
    assert_equal "Anna Keller", users(:anna).reload.name
  end

  test "Rolle und E-Mail lassen sich über das Profilformular nicht ändern" do
    sign_in_as users(:anna)

    patch profile_path, params: {
      user: { name: "Anna", role: "administrator", email_address: "neu@example.test" }
    }

    anna = users(:anna).reload
    assert_predicate anna, :benutzer?
    assert_equal "anna@example.test", anna.email_address
  end
end
