require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  VALID = { name: "Neue Person", email_address: "neu@example.test",
            password: "ein-langes-passwort", password_confirmation: "ein-langes-passwort" }

  test "Registrierungsformular ist für Gäste erreichbar" do
    get signup_path

    assert_response :success
    assert_select "form[action=?]", signup_path
  end

  test "Registrierung legt ein Benutzerkonto an und meldet an" do
    assert_difference [ "User.count", "Session.count" ], 1 do
      post signup_path, params: { user: VALID }
    end

    user = User.find_by!(email_address: "neu@example.test")
    assert_predicate user, :benutzer?
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".site-nav", text: /Neue Person/
  end

  test "mitgesendete Rolle wird ignoriert" do
    post signup_path, params: { user: VALID.merge(role: "administrator") }

    assert_predicate User.find_by!(email_address: "neu@example.test"), :benutzer?
  end

  test "zu kurzes Passwort wird abgelehnt, Eingaben bleiben erhalten" do
    assert_no_difference "User.count" do
      post signup_path, params: { user: VALID.merge(password: "kurz", password_confirmation: "kurz") }
    end

    assert_response :unprocessable_entity
    assert_select ".errors li", text: /Passwort ist zu kurz/
    assert_select "input[name='user[name]'][value=?]", "Neue Person"
    assert_select "input[name='user[email_address]'][value=?]", "neu@example.test"
  end

  test "bereits vergebene E-Mail wird abgelehnt" do
    assert_no_difference "User.count" do
      post signup_path, params: { user: VALID.merge(email_address: "ANNA@example.test") }
    end

    assert_response :unprocessable_entity
    assert_select ".errors li", text: /E-Mail ist bereits vergeben/
  end

  test "Passwortbestätigung muss übereinstimmen" do
    post signup_path, params: { user: VALID.merge(password_confirmation: "etwas-anderes-langes") }

    assert_response :unprocessable_entity
    assert_select ".errors li", text: /Passwort wiederholen/
  end
end
