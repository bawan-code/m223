# Sicherheitsaspekte der Authentifizierung

Überprüfung gemäss Projektarbeit Aufgabe 2 («Sicherheitsüberprüfung»). Jede
Massnahme ist durch einen Test in `test/controllers/` abgesichert.

| Aspekt                      | Umsetzung                                                                                                                                                                                                                                                                                                                          | Nachweis                                                                                    |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Passwort-Hashing            | `has_secure_password` speichert nur einen bcrypt-Hash (`password_digest`), nie den Klartext.                                                                                                                                                                                                                                       | `SessionsControllerTest` «Passwörter werden gehasht gespeichert»                            |
| Passwortregeln              | Mindestens 12 Zeichen (`User::PASSWORD_MIN_LENGTH`), Bestätigung muss übereinstimmen; das Formular empfiehlt Passphrasen statt Sonderzeichen-Regeln. Ein leer abgeschicktes Passwortfeld wird abgewiesen (`has_secure_password` würde es stillschweigend ignorieren und eine Erfolgsmeldung ohne Änderung erzeugen).                                                                                                                                                                               | `RegistrationsControllerTest` «zu kurzes Passwort wird abgelehnt»                           |
| Timing-basierte Enumeration | Anmeldung über `User.authenticate_by`: Bei unbekannter E-Mail wird trotzdem ein bcrypt-Vergleich ausgeführt, damit die Antwortzeit keine Rückschlüsse auf vorhandene Konten zulässt. Falsche E-Mail und falsches Passwort erzeugen dieselbe Meldung. Die Passwort-vergessen-Funktion antwortet ebenfalls für alle Adressen gleich. | `SessionsControllerTest` «dieselbe Meldung», `PasswordsControllerTest` «antwortet … gleich» |
| Rate Limiting               | Höchstens 10 Anmelde- bzw. Reset-Versuche pro 3 Minuten und IP (`rate_limit` in `SessionsController`/`PasswordsController`), danach eine freundliche Wartemeldung.                                                                                                                                                                 | manuell (Rails-Rate-Limiter, Cache-basiert)                                                 |
| CSRF-Schutz                 | Rails-Standard: `protect_from_forgery` in `ActionController::Base`, Token in jedem Formular (`csrf_meta_tags`, `form_with`).                                                                                                                                                                                                       | Integrationstests schicken Requests durch den vollständigen Stack                           |
| Sitzungsverwaltung          | Sitzungen sind Datenbankeinträge (`sessions`); das Cookie enthält nur die signierte Session-ID (`httponly`, `same_site: :lax`). Abmelden löscht die Sitzung serverseitig; ein Passwort-Reset beendet alle Sitzungen.                                                                                                               | `SessionsControllerTest` «Abmelden», `PasswordsControllerTest` «beendet alle Sitzungen»     |
| Gesperrte Konten            | `locked_at` verhindert die Anmeldung; bestehende Sitzungen gesperrter Konten werden beim Laden abgewiesen (zusätzlich zum Löschen beim Sperren, Aufgabe 4).                                                                                                                                                                        | `SessionsControllerTest` «gesperrtes Konto», «bestehende Sitzung … gesperrt»                |
| Passwortänderung            | Das Ändern im angemeldeten Zustand verlangt zusätzlich das aktuelle Passwort (`Current.user.authenticate`), sonst 422. Nach der Änderung werden alle übrigen Sitzungen des Kontos gelöscht, die eigene bleibt bestehen. | `PasswordChangesControllerTest` «ohne korrektes aktuelles Passwort», «andere Geräte werden abgemeldet» |
| E-Mail-Wechsel              | Die neue Adresse wird nur in `unconfirmed_email` vorgemerkt; erst der Klick auf den Bestätigungslink übernimmt sie. Der Link enthält einen signierten, ablaufenden Token (`generates_token_for`, 1 Tag) statt einer Token-Spalte und wird durch die Bestätigung selbst ungültig. Die Mail geht ausschliesslich an die neue Adresse; sie wird erst nach dem erfolgreichen Commit verschickt. | `EmailChangesControllerTest`, `EmailConfirmationsControllerTest` (abgelaufen, wiederverwendet, inzwischen vergeben) |
| Massenzuweisung             | `RegistrationsController` erlaubt nur Name, E-Mail und Passwort; eine mitgesendete `role` wird ignoriert – neue Konten sind immer Benutzer.                                                                                                                                                                                        | `RegistrationsControllerTest` «mitgesendete Rolle wird ignoriert»                           |
| Geschützte Bereiche         | `Authentication`-Concern verlangt standardmässig eine Anmeldung; öffentliche Actions werden explizit mit `allow_unauthenticated_access` freigegeben. Nach der Anmeldung kehrt der Benutzer zur ursprünglich gewünschten Seite zurück.                                                                                              | `SessionsControllerTest` «Gast wird … zurückgebracht»                                       |
| Fehlermeldungen             | Keine technischen Details im UI; Validierungsfehler in Alltagssprache (`config/locales/de.yml`).                                                                                                                                                                                                                                   | alle Controller-Tests prüfen die sichtbaren Meldungen                                       |

Nicht umgesetzt (bewusst ausserhalb des Projektumfangs): Zwei-Faktor-
Authentifizierung, E-Mail-Versand über SMTP, HTTPS-Erzwingung
(`config.force_ssl` gilt nur in Produktion).

**Links in der Entwicklung:** Es wird nichts verschickt
(`config.action_mailer.delivery_method = :test`). Beide Mailer schreiben ihren
Link über `ApplicationMailer#log_link` als eigene Zeile ins Log:

```sh
grep "^--> " log/development.log | tail -2
```

Der Mail-Text selbst wird bewusst **nicht** mehr geloggt
(`config.action_mailer.logger = nil`): er ist quoted-printable codiert und
bricht lange Zeilen mit einem `=` am Zeilenende um – ein daraus kopierter Link
enthält diese `=`, die Signatur stimmt dann nicht mehr und der Token gilt als
ungültig. Die Mail selbst lässt sich unter
<http://localhost:3000/rails/mailers> ansehen.
