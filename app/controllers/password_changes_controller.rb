# Passwort ändern im angemeldeten Zustand. Das aktuelle Passwort ist Pflicht,
# damit ein offen gelassener Browser nicht zur Kontoübernahme reicht.
class PasswordChangesController < ApplicationController
  include SkipAuthorization
  before_action :set_user

  def edit
  end

  def update
    unless @user.authenticate(params[:current_password])
      flash.now[:alert] = t("profiles.current_password_wrong")
      return render :edit, status: :unprocessable_entity
    end

    if @user.update(password_params)
      # Andere Geräte abmelden: die aktuelle Sitzung bleibt, alle übrigen enden.
      @user.sessions.where.not(id: Current.session.id).destroy_all
      redirect_to profile_path, notice: t("profiles.password_changed")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = Current.user
  end

  # `has_secure_password` ignoriert ein leeres Passwort stillschweigend – es gäbe
  # eine Erfolgsmeldung ohne Änderung. Als nil greift die Pflichtfeld-Prüfung.
  def password_params
    { password: params[:password].presence, password_confirmation: params[:password_confirmation] }
  end
end
