# Headless Policy für das Aktivitätsprotokoll (Aufgabe 7): Es gibt kein Modell
# «Activity», geprüft wird nur die Rolle. Aufruf: authorize :activity, :index?
class ActivityPolicy < ApplicationPolicy
  def index? = moderator_or_admin?
end
