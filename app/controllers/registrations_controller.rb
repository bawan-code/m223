class RegistrationsController < ApplicationController
  include SkipAuthorization
  allow_unauthenticated_access

  def new
    redirect_to root_path if authenticated?
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      start_new_session_for @user
      redirect_to root_path, notice: t("auth.registered", name: @user.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    # Rolle und Sperrstatus sind bewusst nicht erlaubt: neue Konten sind immer Benutzer.
    def user_params
      params.expect(user: [ :name, :email_address, :password, :password_confirmation ])
    end
end
