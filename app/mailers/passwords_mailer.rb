class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: t("auth.reset_subject"), to: user.email_address
  end
end
