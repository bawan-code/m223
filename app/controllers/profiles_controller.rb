# Das eigene Profil. Alle Actions arbeiten auf Current.user – es gibt keine
# Route mit Benutzer-ID, also auch keinen Weg zu einem fremden Profil.
class ProfilesController < ApplicationController
  include SkipAuthorization
  before_action :set_user

  def show
  end

  def edit
  end

  def update
    if @user.update(profile_params)
      redirect_to profile_path, notice: t("profiles.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = Current.user
  end

  # Bewusst nur der Name: E-Mail und Passwort haben eigene Abläufe,
  # Rolle und Sperrstatus gehören der Administration.
  def profile_params
    params.expect(user: [ :name ])
  end
end
