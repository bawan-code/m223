require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = "probiert-test-2026"

  test "Anmeldung mit gültigen Daten erstellt eine Sitzung" do
    assert_difference "Session.count", 1 do
      post session_path, params: { email_address: "anna@example.test", password: PASSWORD }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_select ".flash-notice", text: /Willkommen zurück, Anna Keller/
    assert_select ".site-nav", text: /Abmelden/
  end

  test "falsches Passwort und unbekannte E-Mail ergeben dieselbe Meldung" do
    post session_path, params: { email_address: "anna@example.test", password: "falsches-passwort" }
    assert_redirected_to new_session_path(email_address: "anna@example.test")
    wrong_password_alert = flash[:alert]

    post session_path, params: { email_address: "niemand@example.test", password: PASSWORD }
    assert_redirected_to new_session_path(email_address: "niemand@example.test")

    assert_equal wrong_password_alert, flash[:alert]
    assert_equal "E-Mail oder Passwort ist falsch.", flash[:alert]
    assert_equal 0, Session.count
  end

  test "gesperrtes Konto kann sich nicht anmelden" do
    assert_no_difference "Session.count" do
      post session_path, params: { email_address: "locked@example.test", password: PASSWORD }
    end

    assert_redirected_to new_session_path
    assert_match(/gesperrt/, flash[:alert])
  end

  test "Gast wird bei geschützter Seite zur Anmeldung geleitet und danach zurückgebracht" do
    get profile_path
    assert_redirected_to new_session_path

    post session_path, params: { email_address: "anna@example.test", password: PASSWORD }
    assert_redirected_to profile_url
  end

  test "HEAD auf geschützte Seite merkt sich die Seite wie GET" do
    head profile_path
    assert_redirected_to new_session_path

    post session_path, params: { email_address: "anna@example.test", password: PASSWORD }
    assert_redirected_to profile_url
  end

  test "Abmelden beendet die Sitzung" do
    sign_in_as users(:anna)

    assert_difference "Session.count", -1 do
      delete session_path
    end

    assert_redirected_to root_path
    get profile_path
    assert_redirected_to new_session_path
  end

  test "bestehende Sitzung eines gesperrten Kontos wird nicht mehr akzeptiert" do
    sign_in_as users(:anna)
    users(:anna).update!(locked_at: Time.current)

    get profile_path

    assert_redirected_to new_session_path
  end

  test "Passwörter werden gehasht gespeichert" do
    user = users(:anna)

    assert_not_equal PASSWORD, user.password_digest
    assert user.authenticate(PASSWORD)
    assert_match(/\A\$2a\$/, user.password_digest, "bcrypt-Hash erwartet")
  end
end
