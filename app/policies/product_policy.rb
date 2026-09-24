# Der Katalog ist öffentlich lesbar; erfassen darf jede angemeldete Person,
# korrigieren und sperren nur die Moderation (Berechtigungsmatrix 4.3).
class ProductPolicy < ApplicationPolicy
  def index? = true

  # Gesperrte Produkte verschwinden für alle ausser der Moderation – auch über
  # die direkte URL, nicht nur aus der Liste.
  def show? = !record.locked? || moderator_or_admin?

  def create? = angemeldet?
  def new? = create?

  def update? = moderator_or_admin?
  def edit? = update?
  def lock? = moderator_or_admin?
  def unlock? = moderator_or_admin?

  # Produkte werden gesperrt, nie gelöscht: an ihnen hängen fremde Bewertungen.
  def destroy? = false

  # lock_version gehört dazu, sonst greift das optimistische Locking nicht.
  def permitted_attributes
    [ :name, :brand, :description, :category_id, :retail_chain_id, :lock_version ]
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.moderator_or_admin? ? scope.all : scope.visible
    end
  end
end
