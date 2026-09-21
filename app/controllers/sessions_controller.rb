class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: t("auth.rate_limited") }

  def new
    redirect_to root_path if authenticated?
  end

  def create
    # authenticate_by prüft in konstanter Zeit, damit unbekannte E-Mails nicht an der
    # Antwortzeit erkennbar sind; die Meldung ist für beide Fälle dieselbe.
    user = User.authenticate_by(params.permit(:email_address, :password))

    if user.nil?
      redirect_to new_session_path(email_address: params[:email_address]), alert: t("auth.invalid_credentials")
    elsif user.locked?
      redirect_to new_session_path, alert: t("auth.account_locked")
    else
      start_new_session_for user
      redirect_to after_authentication_url, notice: t("auth.signed_in", name: user.name)
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, status: :see_other, notice: t("auth.signed_out")
  end
end
