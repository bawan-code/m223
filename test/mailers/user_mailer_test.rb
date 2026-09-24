require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  NEW_EMAIL = "anna.neu@example.test"

  test "die Bestätigungsmail geht nur an die neue Adresse und enthält einen gültigen Link" do
    user = users(:anna)
    user.update!(unconfirmed_email: NEW_EMAIL)

    mail = UserMailer.email_confirmation(user)

    assert_equal [ NEW_EMAIL ], mail.to
    assert_equal "Neue E-Mail-Adresse bestätigen – Probiert", mail.subject

    token = mail.text_part.body.decoded[%r{/email_confirmations/(\S+)}, 1]
    assert token, "Bestätigungslink fehlt in der Mail"
    assert_equal user, User.find_by_token_for(:email_confirmation, token)
  end
end
