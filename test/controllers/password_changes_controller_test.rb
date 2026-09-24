require "test_helper"

class PasswordChangesControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = "probiert-test-2026"
  NEW_PASSWORD = "ein-ganz-neues-passwort"

  test "Gast wird zur Anmeldung geleitet" do
    get edit_password_change_path

    assert_redirected_to new_session_path
  end

  test "das Formular verlangt das aktuelle und das neue Passwort" do
    sign_in_as users(:anna)

    get edit_password_change_path

    assert_response :success
    assert_select "input[name=current_password]"
    assert_select "input[name=password]"
    assert_select "input[name=password_confirmation]"
    assert_select "form[action=?]", password_change_path do
      assert_select "input[name=_method][value=patch]"
    end
  end

  test "Passwort ändern mit korrektem aktuellem Passwort" do
    sign_in_as users(:anna)

    patch password_change_path, params: {
      current_password: PASSWORD, password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD
    }

    assert_redirected_to profile_path
    assert users(:anna).reload.authenticate(NEW_PASSWORD)
  end

  test "ohne korrektes aktuelles Passwort bleibt das Passwort unverändert" do
    sign_in_as users(:anna)

    patch password_change_path, params: {
      current_password: "falsches-passwort", password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD
    }

    assert_response :unprocessable_entity
    assert_select ".flash-alert", text: /aktuelle Passwort stimmt nicht/
    assert users(:anna).reload.authenticate(PASSWORD)
  end

  test "zu kurzes neues Passwort wird abgelehnt" do
    sign_in_as users(:anna)

    patch password_change_path, params: {
      current_password: PASSWORD, password: "zu-kurz", password_confirmation: "zu-kurz"
    }

    assert_response :unprocessable_entity
    assert_select ".errors li", text: /Passwort ist zu kurz/
    assert users(:anna).reload.authenticate(PASSWORD)
  end

  test "abweichende Bestätigung wird abgelehnt" do
    sign_in_as users(:anna)

    patch password_change_path, params: {
      current_password: PASSWORD, password: NEW_PASSWORD, password_confirmation: "etwas-anderes-langes"
    }

    assert_response :unprocessable_entity
    assert users(:anna).reload.authenticate(PASSWORD)
  end

  test "ein leeres Passwort wird abgelehnt statt still ignoriert" do
    sign_in_as users(:anna)

    patch password_change_path, params: {
      current_password: PASSWORD, password: "", password_confirmation: ""
    }

    assert_response :unprocessable_entity
    assert_select ".errors li", text: /Passwort muss ausgefüllt werden/
    assert users(:anna).reload.authenticate(PASSWORD)
  end

  test "die eigene Sitzung bleibt, andere Geräte werden abgemeldet" do
    anna = users(:anna)
    other_device = anna.sessions.create!
    sign_in_as anna

    patch password_change_path, params: {
      current_password: PASSWORD, password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD
    }

    assert_not Session.exists?(other_device.id)
    get profile_path
    assert_response :success
  end
end
