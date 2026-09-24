# Der Bestätigungslink aus der Mail. Der signierte Token identifiziert das
# Konto, deshalb ist keine Anmeldung nötig – die neue Adresse wird erst hier
# übernommen.
class EmailConfirmationsController < ApplicationController
  include SkipAuthorization
  allow_unauthenticated_access

  def show
    user = User.find_by_token_for(:email_confirmation, params[:token])

    if user.nil? || !user.email_change_pending?
      return redirect_to root_path, alert: t("profiles.confirmation_invalid")
    end

    User.transaction do
      user.update!(email_address: user.unconfirmed_email, unconfirmed_email: nil)
    end

    redirect_to root_path, notice: t("profiles.email_confirmed", email: user.email_address)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    # Jemand anderes hat die Adresse zwischenzeitlich registriert
    redirect_to root_path, alert: t("profiles.email_taken")
  end
end
