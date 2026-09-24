# Aktivitätsprotokoll: wer hat wann was geändert. Die Einträge entstehen
# innerhalb der Transaktionen aus Aufgabe 6 – Bewertung, Aggregat und
# Protokolleintrag sind damit eine Einheit.
class ActivitiesController < ApplicationController
  # Der Zugriff ist alles oder nichts (ActivityPolicy); ein Policy-Scope über
  # die Versionen würde nichts zusätzlich einschränken.
  skip_after_action :verify_policy_scoped

  ENTRIES = 100

  def index
    authorize :activity, :index?

    @versions = PaperTrail::Version.includes(:item).order(created_at: :desc).limit(ENTRIES)
    # Akteure in einer Abfrage nachladen; whodunnit ist eine Benutzer-ID als String.
    @actors = User.where(id: @versions.filter_map(&:whodunnit)).index_by { |user| user.id.to_s }
  end
end
