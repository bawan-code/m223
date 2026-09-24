require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "die Reset-Mail geht an den Benutzer und enthält einen gültigen Link" do
    user = users(:anna)

    mail = PasswordsMailer.reset(user)

    assert_equal [ user.email_address ], mail.to
    assert_equal "Passwort zurücksetzen – Probiert", mail.subject

    token = mail.text_part.body.decoded[%r{/passwords/([^/\s]+)/edit}, 1]
    assert token, "Reset-Link fehlt in der Mail"
    assert_equal user, User.find_by_password_reset_token!(token)
  end
end
