# Benutzerverwaltung: ausschliesslich für Administratoren (Berechtigungsmatrix 4.3).
class UserPolicy < ApplicationPolicy
  def index? = administrator?
  def show? = administrator?
  def update? = administrator?

  # Selbstschutz: ein Administrator darf sich weder aussperren noch löschen –
  # sonst bliebe die Applikation ohne Administration zurück.
  def lock? = administrator? && !own_account?
  def unlock? = administrator?
  def destroy? = administrator? && !own_account?
  def confirm_destroy? = destroy?

  # Name und E-Mail darf der Administrator immer ändern, die Rolle nur bei
  # fremden Konten. Damit ist die eigene Herabstufung auch dann ausgeschlossen,
  # wenn jemand das Feld von Hand mitschickt.
  def permitted_attributes
    attributes = [ :name, :email_address ]
    attributes << :role unless own_account?
    attributes
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.administrator? ? scope.all : scope.none
    end
  end

  private

  def own_account? = user == record
end
