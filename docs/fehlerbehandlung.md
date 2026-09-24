# Fehlerbehandlung und User Feedback

Nachweis zum gleichnamigen Bewertungskriterium. Die Wegleitung verlangt:
ungültige Eingaben, fehlende Berechtigungen und konkurrierende Änderungen
werden **serverseitig** behandelt und verständlich erklärt, Eingaben bleiben
soweit möglich erhalten, die nächste mögliche Handlung ist erkennbar,
erfolgreiche Aktionen werden bestätigt, technische Fehlermeldungen erscheinen
nie ungefiltert.

Alle Meldungen stehen in `config/locales/de.yml`, keine im Code.

## Grundsätze

| Grundsatz | Umsetzung |
| --- | --- |
| Gefährliche Aktionen doppelt absichern | Ein Klick auf «Löschen» in der Benutzerübersicht öffnet nur eine Bestätigungsseite (GET) – ein verklickter Link löscht nichts. Erst das Formular dort schickt `DELETE`, zusätzlich mit `data-turbo-confirm`. Die erste Stufe ist serverseitig und funktioniert auch ohne JavaScript. |
| Serverseitig statt nur im UI | Ausgeblendete Buttons sind Komfort, nicht Schutz. Jede Action prüft die Berechtigung über eine Pundit-Policy (`authorize`); `Admin::BaseController` erzwingt das zusätzlich mit `after_action :verify_authorized`. |
| Formularfehler | Immer `render … status: :unprocessable_entity` mit `shared/_errors` – nie `redirect_to`, dabei gingen die Eingaben verloren. |
| Erfolg bestätigen | Jede schreibende Aktion endet mit `flash[:notice]` in Alltagssprache. |
| Keine technischen Details | Keine Exception-Klassen, SQL-Fragmente oder Stacktraces im UI. `rescue_from` fängt die beiden Fälle ab, die den Benutzer erreichen können. |

## Fälle

| Auslöser | Status | Meldung | Eingaben erhalten | Nächste Handlung | Test |
| --- | --- | --- | --- | --- | --- |
| Gast ruft geschützte Seite auf | 302 | «Bitte melde dich an, um fortzufahren.» | – | Anmeldeformular, danach zurück zur gewünschten Seite (`return_to`) | `SessionsControllerTest` «Gast wird … zurückgebracht» |
| Angemeldeter ohne Berechtigung (z. B. Benutzer im Admin-Bereich) | **403** | «Kein Zugriff» – «Für diese Seite fehlt deinem Konto die Berechtigung.» | – | Link zur Startseite | `Admin::UsersControllerTest` «403 auf allen Admin-Actions», «die 403-Seite erklärt den Grund» |
| Unbekannte oder gelöschte ID | **404** | «Nicht gefunden» – «Diese Seite oder dieser Eintrag existiert nicht (mehr).» | – | Link zur Startseite | `Admin::UsersControllerTest` «unbekannte Benutzer-ID» |
| Falsche Anmeldedaten | 302 | «E-Mail oder Passwort ist falsch.» (identisch für unbekannte E-Mail und falsches Passwort) | E-Mail bleibt im Formular | Erneut versuchen, Link «Passwort vergessen?» | `SessionsControllerTest` «dieselbe Meldung» |
| Anmeldung an gesperrtem Konto | 302 | «Dieses Konto wurde gesperrt. Wende dich an die Administration.» | – | Kontakt zur Administration | `SessionsControllerTest` «gesperrtes Konto» |
| Zu viele Anmeldeversuche | 302 | «Zu viele Versuche. Bitte warte ein paar Minuten.» | – | Später erneut | `rate_limit` in `SessionsController` |
| Registrierung: Passwort zu kurz / E-Mail vergeben / Bestätigung falsch | **422** | «Passwort ist zu kurz …», «E-Mail ist bereits vergeben» | ja (Name, E-Mail) | Formular korrigieren, Link zur Anmeldung | `RegistrationsControllerTest` |
| Profil: leerer Name | **422** | «Name muss ausgefüllt werden» | ja | Formular korrigieren | `ProfilesControllerTest` |
| Passwort ändern ohne korrektes aktuelles Passwort | **422** | «Das aktuelle Passwort stimmt nicht.» | ja | Erneut eingeben | `PasswordChangesControllerTest` |
| Passwort ändern mit leerem Feld | **422** | «Passwort muss ausgefüllt werden» | ja | Formular ausfüllen | `PasswordChangesControllerTest` |
| E-Mail-Wechsel auf vergebene oder eigene Adresse | **422** | «Neue E-Mail wird bereits von einem anderen Konto verwendet» / «ist bereits deine aktuelle Adresse» | ja | Andere Adresse eingeben | `EmailChangesControllerTest` |
| Bestätigungslink ungültig, abgelaufen oder schon benutzt | 302 | «Der Bestätigungslink ist ungültig, abgelaufen oder bereits verwendet. Fordere einen neuen an.» | – | Neuen Link anfordern | `EmailConfirmationsControllerTest` |
| Adresse wurde zwischen Anforderung und Bestätigung vergeben | 302 | «Diese E-Mail-Adresse wurde inzwischen von jemand anderem registriert. Wähle eine andere.» | – | Andere Adresse wählen | `EmailConfirmationsControllerTest` |
| Admin setzt eine bereits vergebene E-Mail | **422** | «E-Mail ist bereits vergeben» | ja (Name und E-Mail) | Formular korrigieren | `Admin::UsersControllerTest` «bereits vergebene E-Mail» |
| Admin will eigenes Konto sperren oder löschen | **403** | «Kein Zugriff» | – | Zurück zur Übersicht | `Admin::UsersControllerTest` «kann sich nicht selbst sperren / löschen» |
| Admin klickt «Löschen» in der Übersicht | 200 | Bestätigungsseite: «Das lässt sich nicht rückgängig machen», mit Anzahl betroffener Bewertungen und dem Hinweis, dass die Produkte im Katalog bleiben | – | «Konto endgültig löschen» oder «Abbrechen» | `Admin::UsersControllerTest` «die Übersicht kann nicht direkt löschen», «die Bestätigungsseite nennt die Folgen» |
| Admin schickt für das eigene Konto eine Rolle mit | 302 | keine – das Feld wird ignoriert, Name und E-Mail werden gespeichert | ja | – | `Admin::UsersControllerTest` «kann sich nicht selbst herabstufen» |

### Noch offen (Aufgabe 6)

Die Konfliktfälle der Kernfunktion aus Qualitätsattribut Q3 – Doppelbewertung,
Produkt-Duplikat, veraltete `lock_version`, bereits übernommene Meldung – werden
hier nachgetragen, sobald sie umgesetzt sind.

## Statische Fehlerseiten

`public/400.html`, `404.html`, `422.html`, `500.html` und
`406-unsupported-browser.html` greifen, wenn der Request den Controller gar
nicht erreicht (Produktion). Sie sind noch die englischen Rails-Vorlagen und
werden vor der Abgabe übersetzt – siehe Projektplan, Querschnitt
«Fehlerbehandlung und User Feedback».
