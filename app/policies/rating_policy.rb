# Eine Bewertung gehört ihrem Verfasser: nur er ändert und löscht sie. Die
# Moderation kann sie sperren, aber nicht umschreiben – sonst stünde am Ende
# eine fremde Meinung unter seinem Namen.
class RatingPolicy < ApplicationPolicy
  def show? = record.aktiv? || owner? || moderator_or_admin?

  def create? = angemeldet? && product_open?
  def new? = create?

  def update? = owner?
  def edit? = update?
  def destroy? = owner?
  def confirm_destroy? = destroy?

  def block? = moderator_or_admin?
  def unblock? = moderator_or_admin?

  def permitted_attributes = [ :stars, :comment ]

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.moderator_or_admin? ? scope.all : scope.active
    end
  end

  private

  def owner? = angemeldet? && record.user_id == user.id

  # Zu einem gesperrten Produkt kommt keine neue Bewertung mehr dazu.
  def product_open? = record.product.present? && !record.product.locked?
end
