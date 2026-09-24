require "test_helper"

class EmailChangesControllerTest < ActionDispatch::IntegrationTest
  NEW_EMAIL = "anna.neu@example.test"

  test "Gast wird zur Anmeldung geleitet" do
    get new_email_change_path

    assert_redirected_to new_session_path
  end

  test "das Formular fragt nach der neuen Adresse und schickt sie an die create-Route" do
    sign_in_as users(:anna)

    get new_email_change_path

    assert_response :success
    assert_select "input[name='user[unconfirmed_email]']"
    assert_select "form[action=?][method=?]", email_change_path, "post" do
      # form_with würde für einen bestehenden Benutzer sonst PATCH überschreiben,
      # die Route nimmt aber nur POST entgegen.
      assert_select "input[name=_method]", false
    end
  end

  test "die neue Adresse wird nur vorgemerkt und eine Bestätigung verschickt" do
    sign_in_as users(:anna)

    assert_enqueued_emails 1 do
      post email_change_path, params: { user: { unconfirmed_email: " ANNA.NEU@example.test " } }
    end

    anna = users(:anna).reload
    assert_equal "anna@example.test", anna.email_address, "die bisherige Adresse gilt weiter"
    assert_equal NEW_EMAIL, anna.unconfirmed_email
    assert_redirected_to profile_path
  end

  test "eine bereits vergebene Adresse wird abgewiesen, ohne Mail zu verschicken" do
    sign_in_as users(:anna)

    assert_no_enqueued_emails do
      post email_change_path, params: { user: { unconfirmed_email: "BEN@example.test" } }
    end

    assert_response :unprocessable_entity
    assert_select ".errors li", text: /Neue E-Mail wird bereits von einem anderen Konto verwendet/
    assert_nil users(:anna).reload.unconfirmed_email
  end

  test "die eigene aktuelle Adresse wird abgewiesen" do
    sign_in_as users(:anna)

    assert_no_enqueued_emails do
      post email_change_path, params: { user: { unconfirmed_email: "anna@example.test" } }
    end

    assert_response :unprocessable_entity
    assert_select ".errors li", text: /bereits deine aktuelle Adresse/
  end

  test "eine unsinnige Adresse wird abgewiesen" do
    sign_in_as users(:anna)

    assert_no_enqueued_emails do
      post email_change_path, params: { user: { unconfirmed_email: "keine-adresse" } }
    end

    assert_response :unprocessable_entity
    assert_select ".errors li", text: /Neue E-Mail ist nicht gültig/
  end

  test "die Bestätigungsmail geht an die neue Adresse und ihr Link schliesst die Änderung ab" do
    sign_in_as users(:anna)

    perform_enqueued_jobs do
      post email_change_path, params: { user: { unconfirmed_email: NEW_EMAIL } }
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ NEW_EMAIL ], mail.to, "die Bestätigung geht an die neue, nicht an die bisherige Adresse"

    link = mail.text_part.body.decoded[%r{/email_confirmations/\S+}]
    assert link, "Bestätigungslink fehlt in der Mail"

    get link

    assert_equal NEW_EMAIL, users(:anna).reload.email_address
  end
end
