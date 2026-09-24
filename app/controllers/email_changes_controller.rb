# E-Mail-Adresse ändern: die neue Adresse wird vorgemerkt und erst nach dem
# Klick auf den Bestätigungslink übernommen (EmailConfirmationsController).
class EmailChangesController < ApplicationController
  before_action :set_user

  def new
  end

  def create
    User.transaction do
      @user.update!(email_change_params)
    end

    # Erst nach dem Commit: eine Mail zu einer Adresse, die gar nicht vorgemerkt
    # werden konnte, wäre irreführend und der Token darin wertlos.
    UserMailer.email_confirmation(@user).deliver_later

    redirect_to profile_path, notice: t("profiles.email_change_requested", email: @user.unconfirmed_email)
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private

  def set_user
    @user = Current.user
  end

  def email_change_params
    params.expect(user: [ :unconfirmed_email ])
  end
end
