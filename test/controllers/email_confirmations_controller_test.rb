require "test_helper"

class EmailConfirmationsControllerTest < ActionDispatch::IntegrationTest
  NEW_EMAIL = "anna.neu@example.test"

  setup do
    @user = users(:anna)
    @user.update!(unconfirmed_email: NEW_EMAIL)
    @token = @user.generate_token_for(:email_confirmation)
  end

  test "der Bestätigungslink übernimmt die vorgemerkte Adresse" do
    get email_confirmation_path(@token)

    @user.reload
    assert_equal NEW_EMAIL, @user.email_address
    assert_nil @user.unconfirmed_email
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".flash-notice", text: /#{NEW_EMAIL}/
  end

  test "der Link funktioniert auch ohne Anmeldung" do
    assert_nil Current.session

    get email_confirmation_path(@token)

    assert_equal NEW_EMAIL, @user.reload.email_address
  end

  test "ein ungültiger Token wird abgewiesen" do
    get email_confirmation_path("kein-gueltiger-token")

    assert_redirected_to root_path
    assert_match(/ungültig/, flash[:alert])
    assert_equal "anna@example.test", @user.reload.email_address
  end

  test "ein abgelaufener Token wird abgewiesen" do
    travel 2.days do
      get email_confirmation_path(@token)
    end

    assert_match(/ungültig/, flash[:alert])
    assert_equal "anna@example.test", @user.reload.email_address
  end

  test "der Link lässt sich nicht ein zweites Mal verwenden" do
    get email_confirmation_path(@token)
    get email_confirmation_path(@token)

    assert_match(/ungültig/, flash[:alert])
    assert_equal NEW_EMAIL, @user.reload.email_address
  end

  test "wird die Adresse zwischenzeitlich vergeben, bleibt die bisherige bestehen" do
    users(:ben).update_columns(email_address: NEW_EMAIL)

    get email_confirmation_path(@token)

    assert_redirected_to root_path
    assert_match(/jemand anderem registriert/, flash[:alert])
    assert_equal "anna@example.test", @user.reload.email_address
  end
end
