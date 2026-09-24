class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    @reset_url = edit_password_url(user.password_reset_token)

    log_link "Passwort zurücksetzen für #{user.email_address}", @reset_url

    mail subject: t("auth.reset_subject"), to: user.email_address
  end
end
