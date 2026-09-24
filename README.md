# Probiert

Community-Plattform zum Bewerten von Supermarktprodukten – kettenübergreifend
(Migros, Coop, Aldi, Lidl …). Projektarbeit im ICT Modul 223
«Multiuser-Applikationen objektorientiert realisieren».

Die Projektdokumentation (Problemstellung, Anforderungen, ERM, Breadboards,
Screens, Locking-Konzept) liegt unter [`docs/`](docs/):

- [`docs/projektantrag.md`](docs/projektantrag.md) – Projektantrag und Dokumentation
- [`docs/projektplan.md`](docs/projektplan.md) – Umsetzungsplan nach Aufgaben 1–8
- [`docs/sicherheit.md`](docs/sicherheit.md) – Sicherheitsaspekte der Authentifizierung
- [`docs/fehlerbehandlung.md`](docs/fehlerbehandlung.md) – Fehlerfälle, Meldungen und User Feedback

## Technologie-Stack

| Bereich | Version |
| --- | --- |
| Ruby | 4.0.6 (verwaltet mit [mise](https://mise.jdx.dev)) |
| Ruby on Rails | 8.1.3.1 |
| Datenbank | SQLite3 |
| Assets | Propshaft, Importmap, Turbo |
| Autorisierung | Pundit |
| Aktivitätsprotokoll | PaperTrail |
| Tests | Minitest (Rails-Standard) |

## Voraussetzungen

- Linux / WSL2 mit `build-essential`, `libssl-dev`, `zlib1g-dev`, `libyaml-dev`, `libffi-dev`, `libgmp-dev`
- [mise](https://mise.jdx.dev/getting-started.html) (installiert Ruby 4.0.6 aus `mise.toml`)
- SQLite3 (`sudo apt-get install sqlite3`)
- Git

## Installation

```sh
git clone <repo-url> m223
cd m223
mise trust
mise install
bundle install
```

## Datenbank aufbauen und Demo-Daten laden

```sh
bin/rails db:setup      # erstellt die Datenbank, führt Migrationen aus und lädt db/seeds.rb
```

## Starten

```sh
bin/rails server
```

Die Applikation läuft unter [http://localhost:3000](http://localhost:3000).

## Tests

```sh
bin/rails test                                   # gesamte Suite
bin/rails test test/models/rating_test.rb        # einzelne Datei
bin/rails test test/models/rating_test.rb:12     # einzelner Test (Zeile)
bin/rubocop                                      # Code-Style
```

## Demo-Konten

`bin/rails db:seed` legt folgende Konten an (Passwort jeweils `probiert-demo-2026`):

| E-Mail | Rolle |
| --- | --- |
| anna@example.test | Benutzer |
| ben@example.test | Benutzer |
| clara@example.test | Benutzer |
| moni@example.test | Moderator |
| max@example.test | Moderator |
| admin@example.test | Administrator |

Für den Performance-Test (Q4) lassen sich zusätzlich 5'000 Produkte erzeugen:

```sh
SEED_PRODUCTS=5000 bin/rails db:seed
```
