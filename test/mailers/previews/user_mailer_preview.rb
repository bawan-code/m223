# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/email_confirmation
  def email_confirmation
    user = User.take
    user.unconfirmed_email = "neue.adresse@example.test"

    UserMailer.email_confirmation(user)
  end
end
