require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "Anforderung antwortet für bekannte und unbekannte Adressen gleich" do
    post passwords_path, params: { email_address: "anna@example.test" }
    assert_redirected_to new_session_path
    known = flash[:notice]

    post passwords_path, params: { email_address: "niemand@example.test" }
    assert_redirected_to new_session_path

    assert_equal known, flash[:notice]
  end

  test "Anforderung verschickt eine Mail nur an bekannte Adressen" do
    assert_enqueued_emails 1 do
      post passwords_path, params: { email_address: "anna@example.test" }
    end

    assert_no_enqueued_emails do
      post passwords_path, params: { email_address: "niemand@example.test" }
    end
  end

  test "gültiger Token setzt das Passwort neu und beendet alle Sitzungen" do
    user = users(:anna)
    sign_in_as user

    put password_path(user.password_reset_token),
        params: { password: "ganz-neues-passwort", password_confirmation: "ganz-neues-passwort" }

    assert_redirected_to new_session_path
    assert user.reload.authenticate("ganz-neues-passwort")
    assert_equal 0, user.sessions.count
  end

  test "ein leeres neues Passwort wird abgelehnt statt still ignoriert" do
    user = users(:anna)

    put password_path(user.password_reset_token), params: { password: "", password_confirmation: "" }

    assert_response :unprocessable_entity
    assert user.reload.authenticate("probiert-test-2026")
  end

  test "ungültiger Token wird abgewiesen" do
    get edit_password_path("kein-gueltiger-token")

    assert_redirected_to new_password_path
    assert_match(/ungültig/, flash[:alert])
  end

  test "zu kurzes neues Passwort wird abgelehnt" do
    user = users(:anna)

    put password_path(user.password_reset_token), params: { password: "kurz", password_confirmation: "kurz" }

    assert_response :unprocessable_entity
    assert user.reload.authenticate("probiert-test-2026")
  end
end
