class UserMailer < ApplicationMailer
  def email_confirmation(user)
    @user = user
    @confirmation_url = email_confirmation_url(user.generate_token_for(:email_confirmation))

    log_link "E-Mail-Bestätigung für #{user.unconfirmed_email}", @confirmation_url

    mail subject: t("profiles.confirmation_subject"), to: user.unconfirmed_email
  end
end
