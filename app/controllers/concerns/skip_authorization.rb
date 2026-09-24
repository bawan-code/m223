# Nimmt einen Controller von der Autorisierungspflicht aus
# (`verify_authorized` / `verify_policy_scoped` im ApplicationController).
#
# Zulässig genau für zwei Fälle:
#
# 1. Öffentliche Seiten ohne Datensatz (Startseite, Anmeldung, Registrierung).
# 2. Selbstbedienung auf dem eigenen Konto: Profil, Passwort, E-Mail-Wechsel.
#    Diese Controller arbeiten ausschliesslich auf `Current.user` und kennen
#    keine ID in der Route – es gibt keinen fremden Datensatz, über den eine
#    Policy entscheiden könnte. Den Zugriffsschutz liefert dort das
#    Authentication-Concern (`require_authentication`).
#
# Alles andere autorisiert über eine Policy.
module SkipAuthorization
  extend ActiveSupport::Concern

  included do
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
  end
end
