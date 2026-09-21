# Geschützter Bereich; wird in Aufgabe 3 (Benutzerprofil) ausgebaut.
class ProfilesController < ApplicationController
  def show
    @user = Current.user
  end
end
