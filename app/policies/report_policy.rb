# Melden darf jede angemeldete Person – ausser der eigenen Bewertung und nicht
# zweimal dieselbe. Entschieden wird eine Meldung nur von der Moderatorin, die
# sie übernommen hat (pessimistische Sperre, Projektantrag 4.4).
class ReportPolicy < ApplicationPolicy
  def create? = angemeldet? && !own_rating? && !already_reported?
  def new? = create?

  def index? = moderator_or_admin?

  # Übernehmen kann nur, was noch frei ist.
  def claim? = moderator_or_admin? && record.moderator_id.nil?

  # Ansehen und entscheiden darf ausschliesslich die übernehmende Person.
  def show? = claimed_by_user?
  def unclaim? = claimed_by_user?
  def release? = claimed_by_user?
  def block? = claimed_by_user?

  def permitted_attributes = [ :reason ]

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.moderator_or_admin? ? scope.all : scope.none
    end
  end

  private

  def own_rating? = record.rating.present? && record.rating.user_id == user&.id

  def already_reported?
    return false if record.persisted? || record.rating_id.blank?

    Report.exists?(rating_id: record.rating_id, reporter_id: user&.id)
  end

  def claimed_by_user? = moderator_or_admin? && record.moderator_id.present? && record.moderator_id == user.id
end
