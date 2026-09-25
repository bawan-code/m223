# Testing

Nachweis zu Projektaufgabe 8 und zu den Qualitätsattributen Q1–Q5 aus
`projektantrag.md` 4.2.

```sh
bin/rails test        # gesamte Suite
bin/rubocop           # Code-Stil
```

*Listing 1: Tests und Code-Stil prüfen*

**Stand:** 240 Tests, 984 Assertions, 0 Fehler, 0 `skip`, Laufzeit **4,0 s**
(Q5 verlangt unter 60 s). 29 Testdateien: 7 Modelle, 5 Policies,
13 Controller, 1 Helper, 2 Mailer, 1 Projektregel.

Die Tests verwenden die separate Testdatenbank von Rails und Fixtures aus
`test/fixtures` (die Seeds sind ausschliesslich Demo-Daten). `sign_in_as` in
`test/test_helper.rb` meldet eine Fixture-Person an; `raising` ersetzt dort
kurzzeitig eine Klassenmethode, um Gleichzeitigkeitsfälle auszulösen, die sich
in einem einzelnen Prozess sonst nicht herstellen lassen.

## Funktionale Anforderungen

*Tabelle 1: Funktionale Anforderungen und ihre Tests*

| Nr. | Anforderung | Geprüft durch | Ergebnis |
| --- | --- | --- | --- |
| F1 | Registrieren, Anmelden, Abmelden, Sitzungen | `RegistrationsControllerTest`, `SessionsControllerTest`, `PasswordsControllerTest` | bestanden |
| F2 | Produkte nach Bezeichnung, Marke, Kategorie und Kette suchen und filtern, nach Bewertung sortieren | `ProductsControllerTest` «Suche findet über Bezeichnung und Marke», «Filter nach Kategorie und Handelskette», «die Liste lässt sich nach bester und nach schlechtester Bewertung sortieren», `ProductTest` | bestanden |
| F3 | Bewerten mit 1–5 Sternen, genau eine Bewertung pro Benutzer und Produkt | `RatingsControllerTest`, `RatingTest` «Sterne müssen zwischen 1 und 5 liegen», «pro Benutzer und Produkt höchstens eine Bewertung» | bestanden |
| F4 | Eigene Bewertung ändern und löschen, Aggregate werden nachgeführt | `RatingsControllerTest` «ändern/löschen korrigiert die Aggregate», `RatingTest` | bestanden |
| F5 | Detailseite mit Durchschnitt, Anzahl, Verteilung und Kommentaren | `ProductsControllerTest` «die Detailseite zeigt Durchschnitt, Anzahl, Verteilung und Kommentare» | bestanden |
| F6 | Produkte erfassen, Duplikate verhindern | `ProductsControllerTest` «Duplikat wird abgewiesen», «auch der Unique-Index», `ProductTest` | bestanden |
| F7 | Bewertungen melden; Moderation übernimmt und entscheidet | `ReportsControllerTest`, `Moderation::ReportsControllerTest`, `ReportTest` | bestanden |
| F8 | Moderation korrigiert und sperrt Produkte | `ProductsControllerTest` «Moderatoren korrigieren Produktdaten», «sperren und entsperren» | bestanden |
| – | Benutzerprofil, Passwort- und E-Mail-Wechsel | `ProfilesControllerTest`, `PasswordChangesControllerTest`, `EmailChangesControllerTest`, `EmailConfirmationsControllerTest` | bestanden |
| – | Benutzerverwaltung durch die Administration | `Admin::UsersControllerTest` | bestanden |
| – | Aktivitätsprotokoll | `ActivitiesControllerTest`, `ActivityLogTest` | bestanden |

## Qualitätsattribute

### Q1 – Datenkonsistenz

*Tabelle 2: Nachweis Q1 – Datenkonsistenz*

| Anforderung | Test | Ergebnis |
| --- | --- | --- |
| 50 Bewertungen → Anzahl und Durchschnitt stimmen exakt | `RatingTest` «auch nach 50 Bewertungen stimmen Anzahl und Summe» | `ratings_count == 50`, `ratings_sum` gleich der Summe der gespeicherten Sterne |
| Zwei gleichzeitige Bewertungen desselben Benutzers → genau eine | `RatingTest` «der Unique-Index verhindert eine zweite Bewertung», `RatingsControllerTest` «vom Unique-Index abgefangen» | `RecordNotUnique`, danach genau eine Bewertung |
| Aggregate nach Ändern, Löschen und Sperren | `RatingTest` «ändern, zurückziehen und sperren halten die Aggregate korrekt», `ReportTest` «Sperren … nimmt die Bewertung aus dem Durchschnitt» | Aggregate entsprechen immer `ratings.active` |

Durchgesetzt wird das an einer einzigen Stelle: `Rating.with_aggregates` lädt
das Produkt innerhalb der Transaktion, führt die Änderung aus und berechnet die
Aggregate neu. Alle fünf Wege (`submit!`, `change!`, `withdraw!`, `block!`,
`unblock!`) gehen hindurch.

### Q2 – Korrekte Autorisierung

Für jede Rolle mindestens ein erlaubter und ein verweigerter Zugriff, geprüft
in `test/policies/` und zusätzlich über echte Requests in den Controller-Tests.

*Tabelle 3: Erlaubte und verweigerte Zugriffe je Rolle (Q2)*

| Rolle | erlaubt (Beispiel) | verweigert (Beispiel) |
| --- | --- | --- |
| Gast | Produktsuche und Detailseite | bewerten, melden, gesperrtes Produkt ansehen |
| Benutzer | erfassen, bewerten, eigene Bewertung ändern | fremde Bewertung ändern (403), Produktdaten korrigieren, Meldungsliste |
| Moderator | Produkte korrigieren und sperren, Meldungen übernehmen | fremde Bewertung umschreiben, fremde Meldung entscheiden, Benutzerverwaltung |
| Administrator | Benutzerdetails, Rollen, Konten sperren und löschen | eigenes Konto sperren, löschen oder herabstufen; fremde Meldung entscheiden |

Direkte Requests ohne sichtbare Schaltfläche werden ebenfalls geprüft
(`Admin::UsersControllerTest` «Benutzer erhält auf allen Admin-Actions 403»,
`RatingsControllerTest` «eine mitgeschickte fremde user_id wird ignoriert»).
`ApplicationController` erzwingt mit `verify_authorized` und
`verify_policy_scoped`, dass keine Action die Prüfung vergisst – eine vergessene
`authorize`-Zeile lässt die Tests sofort mit
`Pundit::AuthorizationNotPerformedError` scheitern.

### Q3 – Verständliche Konfliktbehandlung

Alle Fälle mit Meldung, erhaltenen Eingaben und nächster Handlung sind in
[`fehlerbehandlung.md`](fehlerbehandlung.md) einzeln aufgeführt. Die drei vom
Qualitätsattribut geforderten:

*Tabelle 4: Nachweis der drei Konfliktfälle aus Q3*

| Konflikt | Test | Ergebnis |
| --- | --- | --- |
| Doppelbewertung | `RatingsControllerTest` «führt zur bestehenden statt eine neue anzulegen» | Weiterleitung auf die eigene Bewertung, die neuen Eingaben stehen im Formular, gespeichert bleibt zunächst die alte |
| Duplikat beim Erfassen | `ProductsControllerTest` «Duplikat wird abgewiesen und auf das bestehende Produkt verwiesen» | 422, Link auf das bestehende Produkt, Eingaben bleiben unverändert stehen |
| Konkurrierende Bearbeitung | `ProductsControllerTest` «eine veraltete Version wird abgewiesen» (zwei `open_session`) | 422, aktuelle Werte neben den eigenen Eingaben, die erste Änderung bleibt bestehen |

### Q4 – Performance der Suche

Gemessen mit `script/search_benchmark.rb`: vollständige Requests auf
`/products` – Routing, Policy-Scope, Abfrage und Rendern der Trefferliste –
mit zehn gleichzeitigen Threads, 100 Anfragen, auf einer eigenen Datenbank.

```sh
export DATABASE_URL="sqlite3:storage/benchmark.sqlite3"
bin/rails db:prepare
SEED_PRODUCTS=5000 bin/rails db:seed
RAILS_MAX_THREADS=10 bin/rails runner script/search_benchmark.rb
rm storage/benchmark.sqlite3*
```

*Listing 2: Messung Q4 auf einer eigenen Datenbank*

*Tabelle 5: Antwortzeiten der Produktsuche bei 5'000 Produkten und zehn gleichzeitigen Anfragen (Q4)*

| Messung | Median | 95. Perzentil | Maximum |
| --- | --- | --- | --- |
| erste Messung, ohne Seitenausgabe | 1559 ms | **2271 ms** | 2652 ms |
| nach Einführung der Seitenausgabe | 159 ms | **223 ms** | 290 ms |

**Q4 war zunächst verfehlt** (Grenzwert 2000 ms). Die Einzelmessung zeigte,
woran es lag: Die Suche selbst brauchte 46 ms (4 Treffer) bis 79 ms
(503 Treffer), das Rendern der vollständigen Liste mit 5020 Karten dagegen
732 ms – und unter zehn gleichzeitigen Anfragen entsprechend mehr. Der Aufwand
lag also nicht in der Abfrage, sondern in der unbegrenzten Ausgabe.

Behoben durch `ProductsController::PER_PAGE` mit Blätterleiste (gemessen
mit 24 Karten pro Seite; seit dem 24.09.2026 sind es 12, was die Ausgabe
nur weiter verkleinert): Die
Antwortzeit hängt jetzt an der Seitengrösse statt an der Kataloggrösse.
Abgesichert durch `ProductsControllerTest` «lange Trefferlisten werden
seitenweise ausgegeben» – der Test prüft, dass nie mehr als `PER_PAGE` Karten
gerendert werden, unabhängig von der Anzahl Produkte.

### Q5 – Testbarkeit und Wartbarkeit

Alle Modelle und alle Autorisierungsregeln der 1. Iteration sind abgedeckt, die
Suite läuft grün in 4,0 s (Grenzwert 60 s) und enthält kein `skip`. Zusätzlich
laufen `bin/rubocop` ohne Beanstandung und `bin/brakeman` ohne Befund;
beides ist in der CI (`.github/workflows/ci.yml`) hinterlegt.

## Aussagekraft der Tests

Gemäss Aufgabe 8.4 wurde gezielt ein Fehler eingebaut, die betroffenen Tests
wurden **vorhergesagt**, die Suite ausgeführt und der Fehler zurückgebaut.

**Eingriff:** `RatingPolicy#destroy?` von `owner?` auf `true` geändert – jede
Person dürfte damit jede Bewertung löschen.

**Vorhergesagt:** `RatingPolicyTest` «nur der Verfasser ändert und löscht seine
Bewertung», `RatingsControllerTest` «eine fremde Bewertung lässt sich weder
ändern noch löschen», `RatingsControllerTest` «die Bestätigungsseite einer
fremden Bewertung ist gesperrt».

**Tatsächlich:** fünf Tests scheiterten – die drei vorhergesagten sowie
`RatingPolicyTest` «Gäste dürfen nicht bewerten» und «Moderatoren sperren fremde
Bewertungen, schreiben sie aber nicht um». Beide prüfen `destroy?` als Teil
ihrer Rollenzusicherung mit; die Regel ist also breiter abgesichert als
angenommen. Nach dem Zurückbauen: 230 Tests grün.

Dieselbe Gegenprobe wurde bei jeder Aufgabe angewandt, unter anderem: `recalculate_aggregates!` aus der
Transaktion entfernt (8 Tests rot), die Prüfung in `Report#claim!` entfernt
(1 Test rot), `set_paper_trail_whodunnit` entfernt (3 Tests rot),
`permitted_attributes` ohne Selbstschutz (2 Tests rot).

## Was die Tests nicht abdecken

- **CSS und Layout.** Die Tests prüfen das Markup, nicht die Darstellung. Zwei
  Fehler sind dadurch bis in den Browser gelangt: ein leeres Filterpanel auf
  grossen Bildschirmen und die zunächst falsch platzierte Produktbeschreibung.
  Beide sind inzwischen so abgesichert, wie es ohne Browser möglich ist
  (Vorhandensein und Reihenfolge der Elemente).
- **Echte Gleichzeitigkeit.** Die Konflikte werden sequenziell mit zwei
  Sitzungen beziehungsweise über gezielt ausgelöste Datenbankfehler geprüft.
  Unter SQLite serialisiert `BEGIN IMMEDIATE` die Schreiber ohnehin; ein echter
  Lasttest mit parallelen Schreibvorgängen wäre erst bei einer anderen Datenbank
  aussagekräftig.
- **E-Mail-Versand.** In der Entwicklung wird nichts verschickt; geprüft werden
  Inhalt und Gültigkeit der Links, nicht die Zustellung.
