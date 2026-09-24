# Projektplan «Probiert» – Umsetzung in Aufgaben 1–8

## Kontext

Der Projektantrag (`docs/projektantrag.md`) ist vollständig: Anforderungen F1–F12,
Qualitätsattribute Q1–Q5, drei Rollen, Locking-Konzept (4.4), ERM (4.5), acht
Breadboards (4.6) und neun Screens (4.7).
Die Kursunterlagen geben die Reihenfolge der Umsetzung vor
(`ict-modul-223-teilnehmerunterlagen/README.md`, Tag 3–4, Aufgaben 1–8) und die
Muster, die der Dozent erwartet:

- `bin/rails generate authentication` (Rails-8-Generator: `User` mit
  `email_address`/`password_digest`, `Session`-Model, `Current.user`,
  `Authentication`-Concern, `authenticate_by`, Rate-Limiting) – nicht Devise.
- Pundit-Policies mit `pundit_user` → `Current.user`; Policies müssen Gäste
  (`user == nil`) behandeln. Ausgeblendete Buttons ersetzen keine Serverprüfung.
- Optimistisches Locking via `lock_version`; unter SQLite/Rails 8.1 startet jede
  Transaktion mit `BEGIN IMMEDIATE` (nur ein Schreiber), `lock!` fügt keine
  Zeilensperre hinzu – Record **innerhalb** der Transaktion laden, Transaktion
  kurz halten.
- Minitest mit Fixtures, `sign_in_as` in `test/test_helper.rb`, 422 bei
  ungültigen Formularen (Turbo), `render … status: :unprocessable_entity`.
- Abgabe: `README.md` (Wie ausführen), `docs/` (Was und Warum), alle Tests grün.

Bewertet wird nach `docs/bewertung.md` (15 Kriterien à 2 Punkte). Die Kriterien
der Gruppe «Multi-User-Applikation» decken die Aufgaben 2–8 ab; «Projektqualität»
und «Domänenmodell» hängen an den Querschnittsabschnitten und am Abschluss weiter
unten. Die Wegleitung konkretisiert sie (`guides/projektarbeit/wegleitung.md`,
Abschnitte «Dokumentation» und «Applikation / Code»).

**Konventionen und Qualitätssicherung** (Bewertungskriterium «Konventionen
beachtet») – gilt für jeden Commit, nicht nur am Schluss:

- `bin/rails test` und `bin/rubocop` (rubocop-rails-omakase) müssen grün sein;
  keine `skip`, keine auskommentierten Tests.
- Die CI (`.github/workflows/ci.yml`) fährt zusätzlich `bin/brakeman` und
  `bin/bundler-audit` – beides muss ohne neue Befunde durchlaufen.
- Rails-Namenskonventionen durchgehend: Generatoren statt Handarbeit, Modelle
  im Singular, Controller im Plural, Tests nach der geprüften Klasse benannt
  (`RatingTest`, `RatingsControllerTest`, `RatingPolicyTest`).
- Sprache: Klassen- und Methodennamen englisch (Rails-Konvention), alles
  Sichtbare – UI, Enum-Werte, Fehlermeldungen, Kommentare, Doku, Commits –
  deutsch. Die Zuordnung hält das Glossar im Projektantrag fest (Abschluss).

Stack (fix): Ruby 4.0.6 (mise), Rails 8.1.3.1, SQLite3, Propshaft, Minitest,
Pundit, PaperTrail. Sprache in UI, Docs und Commits: Deutsch.

Zwei kleine Abweichungen vom ERM, die aus dem Generator folgen und in
`docs/projektantrag.md` 4.5 nachgeführt werden:

1. `users.email` heisst `users.email_address` (Generator-Konvention).
2. Zusätzliche Entität `SESSION` (`user_id`, `ip_address`, `user_agent`) – eine
   Datenbank-Sitzung pro Login, User 1—n Session.
3. Statt der Spalte `email_confirmation_token` wird `generates_token_for`
   (signierter, ablaufender Token ohne Spalte) verwendet; bleibt
   `unconfirmed_email`.

---

## Aufgabe 0: Projekt aufsetzen (Voraussetzung, Tag 3 Start) ✅ erledigt

Im Repo-Root `/home/bawan/Projekt/m223` (Git existiert bereits, App wird
direkt hier hinein generiert, nicht in einen Unterordner):

```sh
rails new . --asset-pipeline propshaft --skip-jbuilder
# Gemfile: gem "json", "~> 2.0"   (JSON 3 inkompatibel mit Cookie-Handling)
# Gemfile: gem "pundit", gem "paper_trail"
bundle install
echo '[tools]\nruby = "4.0.6"' > mise.toml
```

- `.gitignore` von `rails new` mit dem bestehenden zusammenführen; die
  Einträge `ict-modul-223-teilnehmerunterlagen/*`, `projektantrag.md` und
  `CLAUDE.md` bleiben; `docs/` wird versioniert (Abgabepflicht).
- `config/application.rb`: `config.i18n.default_locale = :de`,
  `config.time_zone = "Bern"`; `config/locales/de.yml` mit
  `rails-i18n`-Übersetzungen für ActiveRecord-Fehlermeldungen (Gem
  `rails-i18n`) – damit Validierungsfehler auf Deutsch erscheinen.
- Layout `app/views/layouts/application.html.erb`: Kopfzeile gemäss Screens
  (Logo → Produktsuche, globales Suchfeld, Benutzermenü), Flash-Bereich für
  `notice` / `alert`, minimales CSS in `app/assets/stylesheets/application.css`.
- Commit «Rails-App aufsetzen».

**Verifikation:** `bin/rails server` zeigt Startseite; `bin/rails test` grün (leer).

---

## Aufgabe 1: Datenbank und Modelle (Tag 3) ✅ erledigt

Ziel: Alle Entitäten aus ERM 4.5 mit Validierungen, Assoziationen, Indizes und
Demo-Seeds. Noch keine Controller ausser dem generierten Auth.

### Generatoren (in dieser Reihenfolge)

```sh
bin/rails generate authentication          # users, sessions, Current, Authentication
bin/rails g migration AddProfileToUsers name:string role:integer unconfirmed_email:string locked_at:datetime
bin/rails g model Category name:string:uniq
bin/rails g model RetailChain name:string:uniq
bin/rails g model Product name:string brand:string name_normalized:string brand_normalized:string description:text category:references retail_chain:references created_by:references ratings_count:integer ratings_sum:integer locked_at:datetime lock_version:integer
bin/rails g model Rating user:references product:references stars:integer comment:text status:integer
bin/rails g model Report rating:references reporter:references moderator:references reason:integer status:integer claimed_at:datetime decided_at:datetime
```

Migrationen von Hand nachbessern:

- `users.role` `default: 0, null: false`; `products.ratings_count/ratings_sum`
  `default: 0, null: false`; `products.lock_version` `default: 0, null: false`;
  `ratings.status` und `reports.status` `default: 0, null: false`.
- `created_by`, `reporter`, `moderator` → `foreign_key: { to_table: :users }`,
  `moderator` `null: true`.
- Unique-Indizes (setzen die Fachregeln bei parallelen Requests durch):
  - `products (name_normalized, brand_normalized, retail_chain_id)`
  - `ratings (user_id, product_id)`
  - `reports (rating_id, reporter_id)`
- Suchindizes: `products.name_normalized`, `products.brand_normalized`,
  `products.category_id`, `products.retail_chain_id` (Q4).

### Modelle

- `User`: `has_secure_password` (vom Generator), `normalizes :email_address`,
  `validates :name, presence`, `validates :email_address, uniqueness`,
  `validates :password, length: { minimum: 12 }, allow_nil: true`,
  `enum :role, { benutzer: 0, moderator: 1, administrator: 2 }, default: :benutzer`,
  `has_many :products, foreign_key: :created_by_id`, `has_many :ratings`,
  `has_many :reports, foreign_key: :reporter_id`, `has_many :sessions`.
  Hilfsmethoden: `moderator_or_admin?`, `locked?`.
- `Category`, `RetailChain`: `validates :name, presence, uniqueness`.
- `Product`: `belongs_to :category, :retail_chain, :created_by (User)`,
  `has_many :ratings, dependent: :destroy`, `normalizes :name, :brand` (strip,
  squish), `before_validation :set_normalized_fields` (downcase + squish),
  `validates :name, :brand, presence`, `validates :name_normalized, uniqueness:
  { scope: [:brand_normalized, :retail_chain_id] }` (freundliche Meldung; der
  Index bleibt die Absicherung), `scope :visible` (`locked_at: nil`),
  `scope :search(q)` (LIKE auf beide normalisierten Spalten), `average_rating`
  (`ratings_sum.fdiv(ratings_count)` oder nil), `locked?`,
  `stars_distribution` (`ratings.active.group(:stars).count`).
- `Rating`: `belongs_to :user, :product`, `enum :status, { aktiv: 0, gesperrt: 1 }`,
  `validates :stars, inclusion: 1..5`, `validates :user_id, uniqueness: { scope:
  :product_id }`, `validate :product_not_locked, on: :create`,
  `scope :active`.
- `Report`: `belongs_to :rating, :reporter (User), :moderator (User, optional)`,
  `enum :reason, { beleidigend: 0, spam: 1, kein_bezug: 2, anderes: 3 }`,
  `enum :status, { offen: 0, in_bearbeitung: 1, freigegeben: 2, gesperrt: 3 }`,
  `validate :not_own_rating`, uniqueness `reporter_id` scoped `rating_id`.

### Seeds (`db/seeds.rb`)

Demo-Konten (Passwort jeweils `probiert-demo-2026`): `anna@example.test`
(Benutzer), `ben@example.test` (Benutzer), `moni@example.test` (Moderatorin),
`max@example.test` (Moderator), `admin@example.test` (Administrator).
6 Kategorien, 4 Handelsketten, ~20 Produkte mit Bewertungen, 2 offene Meldungen.
Optional `SEED_PRODUCTS=5000 bin/rails db:seed` für den Q4-Test.

**Verifikation:** `bin/rails db:setup`; in `bin/rails c`: doppelte Bewertung
wirft `ActiveRecord::RecordNotUnique` bei `insert_all`, Validierung greift bei
`create`. Erste Model-Tests (`test/models/product_test.rb`,
`rating_test.rb`) für Validierungen und Unique-Regeln. Commit.

### Nachträge (24.09.2026, nach der Überprüfung von Aufgabe 0–2)

Drei Stellen des Datenmodells hielten der Prüfung nicht stand und wurden mit
eigenen Migrationen korrigiert:

- `reports.reason` hatte `default: 0`: eine Meldung ohne gewählten Grund wurde
  still zu «beleidigend» und war gültig. Der Default ist entfernt, `reason`
  bleibt nil und die Enum-Validierung weist das Formular ab
  (`RemoveDefaultFromReportsReason`).
- `products.created_by_id` war `null: false` und `User has_many :products`
  stand auf `restrict_with_error` – damit liess sich kein Konto löschen (4.4).
  Die Spalte ist jetzt nullable, die Assoziation `dependent: :nullify`, und
  `Product` verlangt den Ersteller nur noch `on: :create`
  (`AllowProductsWithoutCreator`).
- `categories.name` / `retail_chains.name` hatten einen schreibweise-abhängigen
  Unique-Index, die Modellvalidierung war `case_sensitive: false`. «Migros» und
  «MIGROS» konnten deshalb nebeneinander entstehen. Beide Tabellen haben nun –
  wie `products` – eine Spalte `name_normalized` mit Unique-Index; die
  gemeinsame Normalisierung liegt in `app/models/concerns/normalization.rb`
  (`AddNameNormalizedToStammdaten`).

---

## Aufgabe 2: Benutzerauthentifizierung (Tag 3) ✅ erledigt

Ziel: F1 – Registrieren, Anmelden, Abmelden, Sitzungen; Sicherheitsaspekte.

- Generierten `SessionsController`, `Authentication`-Concern, `Current` prüfen
  und auf Deutsch anpassen. `PasswordsController` (Reset) bleibt, Link wird im
  Log ausgegeben (kein SMTP).
- `RegistrationsController#new/#create` (`resource :registration`), Formular
  gemäss Screen 2; nach Erfolg `start_new_session_for user` → Produktsuche.
  `skip_before_action :require_authentication`.
- `Authentication`: `allow_unauthenticated_access` in Controllern mit
  öffentlichem Lesezugriff (Produkte index/show); `request_authentication`
  merkt sich `return_to` → nach Login zurück zum Produkt (Breadboard 1).
- Gesperrte Konten (`locked_at`) können sich nicht anmelden; bestehende
  Sessions werden beim Sperren gelöscht (Aufgabe 4).
- Sicherheit prüfen und in `docs/` festhalten: bcrypt-Hash, min. 12 Zeichen,
  `User.authenticate_by` (konstante Zeit, eine Fehlermeldung für beide Fälle),
  CSRF-Token (Rails-Default), `rate_limit` auf `sessions#create` (Generator).
- Navigation: angemeldet → Name, Rolle, Abmelden (`data: { turbo_method: :delete }`);
  Gast → Anmelden, Registrieren.
- Platzhalter-Startseite = `products#index` (leer bis Aufgabe 6, `root "products#index"`).

**Verifikation:** Controller-Tests `registrations_controller_test.rb`,
`sessions_controller_test.rb`: Registrierung legt User an und meldet an;
kurzes Passwort → 422; falsche Daten → gleiche Meldung; gesperrtes Konto
abgewiesen; Gast wird bei geschützter Route umgeleitet. Commit.

---

## Aufgabe 3: Benutzerprofil (Tag 3) ✅ erledigt

Ziel: Profil ansehen, Name und Passwort ändern, E-Mail mit Bestätigung ändern.

- `resource :profile, only: [:show, :edit, :update]` → `ProfilesController`,
  arbeitet immer auf `Current.user` (keine ID in der URL → kein Fremdzugriff).
- Passwort ändern: eigenes Formular `resource :password_change` oder Teil des
  Profils; erfordert `current_password`
  (`Current.user.authenticate(params[:current_password])`), sonst 422.
- E-Mail ändern: `resource :email_change, only: [:new, :create]` +
  `get "email_confirmations/:token" → email_confirmations#show`.
  - `User.generates_token_for :email_confirmation, expires_in: 1.day do
    unconfirmed_email end`.
  - `create`: `User.transaction { user.update!(unconfirmed_email: …) }`, danach
    `UserMailer.email_confirmation(user).deliver_later` – Mail nur nach
    erfolgreichem Commit (Anforderung aus der Aufgabenstellung).
    `config.action_mailer.delivery_method = :test` in development plus
    `Rails.logger.info confirmation_url` im Mailer.
  - `show`: `User.find_by_token_for(:email_confirmation, token)` →
    `email_address = unconfirmed_email`, `unconfirmed_email = nil`.
- `UserMailer` + `app/views/user_mailer/email_confirmation.text.erb`.

**Verifikation:** Tests: fremdes Profil nicht erreichbar (Route existiert
nicht), Passwortänderung ohne korrektes aktuelles Passwort → 422,
E-Mail-Wechsel setzt nur `unconfirmed_email`, Bestätigung übernimmt sie,
abgelaufener/ungültiger Token → Meldung. Commit.

Umgesetzt wie geplant, mit zwei Ergänzungen:

- Beim Vormerken der neuen Adresse prüft `User#unconfirmed_email_available`
  bereits, ob sie vergeben oder die eigene ist – sonst liefe der Benutzer erst
  nach dem Klick auf den Bestätigungslink in den Fehler. Der
  Gleichzeitigkeitsfall (jemand registriert die Adresse dazwischen) wird beim
  Bestätigen abgefangen und in Alltagssprache gemeldet.
- Eine erfolgreiche Passwortänderung beendet alle übrigen Sitzungen des Kontos;
  die eigene bleibt bestehen (`docs/sicherheit.md`).

---

## Aufgabe 4: Benutzerverwaltung (Tag 3) ✅ erledigt

Ziel: Admin-Bereich mit Benutzerübersicht, Bearbeiten der Benutzerdetails,
Rollen, Kontosperrung; erste Policy. Deckt `exercises/benutzerverwaltung.md`
Punkt 1–4 ab.

- `bin/rails g pundit:install`; `ApplicationController` includes
  `Pundit::Authorization`, `def pundit_user = Current.user`,
  `rescue_from Pundit::NotAuthorizedError` → `render "errors/forbidden",
  status: :forbidden` (Q2 verlangt 403, keine Umleitung). Hier entsteht auch
  die 404-Behandlung – Details im Querschnitt «Fehlerbehandlung und User
  Feedback» weiter unten.
- `namespace :admin do resources :users, only: [:index, :edit, :update, :destroy];
  patch "users/:id/lock", "users/:id/unlock" end`, `Admin::BaseController`
  (`before_action { authorize [:admin, :user] }` bzw. `verify_authorized`),
  `Admin::UsersController`.
- `UserPolicy`: `index?/edit?/update?/lock?/destroy?` nur `administrator?`;
  eigenes Konto nicht sperren, nicht löschen, nicht herabstufen
  (`record != user`). Rollenänderung nur über erlaubte `permitted_attributes`.
- **Benutzerdetails bearbeiten** (`Admin::UsersController#edit/#update`,
  Aufgabenstellung Punkt 2): ein Formular mit Name, E-Mail und Rolle.
  - `permitted_attributes` in `UserPolicy`: `[:name, :email_address]`, dazu
    `:role` nur, wenn `record != user` – so kann sich ein Administrator nicht
    selbst herabstufen, und Rolle/Sperrstatus sind nirgends über
    Massenzuweisung erreichbar.
  - Die E-Mail wird hier **direkt** gesetzt, ohne Bestätigungslink – bewusst
    anders als der Selbstbedienungsweg aus Aufgabe 3: der Administrator handelt
    absichtlich, die Änderung landet im Aktivitätsprotokoll (Aufgabe 7), und ein
    Bestätigungslink an eine fremde Adresse würde den Vorgang nur blockieren.
    Ein hängiges `unconfirmed_email` wird dabei verworfen.
  - Eindeutigkeit sichern Validierung und Unique-Index (`users.email_address`);
    eine bereits vergebene Adresse → `flash.now[:alert]`, `render :edit,
    status: :unprocessable_entity`, Eingaben bleiben stehen (Q3).
- Konto sperren: `locked_at` setzen + `user.sessions.destroy_all` in einer
  Transaktion.
- Konto löschen (4.4): `User.transaction do` Bewertungen löschen und für jedes
  betroffene Produkt Aggregate neu berechnen (`Product#recalculate_aggregates!`
  ist bereits in Aufgabe 1 entstanden), dann `user.destroy!`.
  Meldungen des Users: `reporter` bleibt via `dependent: :destroy` weg,
  `moderator_id` → `nullify`. Die vom Konto erfassten **Produkte bleiben im
  Katalog** und verlieren nur den Ersteller (`dependent: :nullify`, siehe
  Nachträge zu Aufgabe 1); die Aggregate der Produkte müssen daher auch hier
  stimmen.
- Views gemäss Wegleitung: Übersicht als Tabelle (Name, E-Mail, Rolle, Status,
  Aktionen), Bearbeitungsformular mit Name, E-Mail und Rollen-Auswahl; die
  Rollen-Auswahl fehlt beim eigenen Konto.

**Verifikation:** `admin/users_controller_test.rb`: Benutzer und Moderator →
403 (auch auf `edit`/`update`, nicht nur auf `index`); Admin sieht Liste,
ändert **Name und E-Mail** eines Benutzers, ändert die Rolle, sperrt Konto
(Session weg, Login abgewiesen), kann sich nicht selbst sperren und nicht
selbst herabstufen; bereits vergebene E-Mail → 422 mit Meldung und erhaltenen
Eingaben. `user_policy_test.rb` prüft zusätzlich `permitted_attributes`.
Commit.

Umgesetzt wie geplant, mit drei Präzisierungen:

- Statt `authorize [:admin, :user]` im `Admin::BaseController` autorisiert jede
  Action einzeln (`authorize User` bzw. `authorize @user`) – so wie es die
  Kursübung zeigt. Der Basiscontroller erzwingt dafür
  `after_action :verify_authorized`; das globale `verify_authorized` für die
  ganze Applikation folgt in Aufgabe 5.
- Die vergebene E-Mail meldet der `shared/_errors`-Block statt
  `flash.now[:alert]` – gleiche Darstellung wie in allen anderen Formularen der
  Applikation.
- Die 404-Behandlung (`rescue_from ActiveRecord::RecordNotFound`) und die Seiten
  `app/views/errors/{forbidden,not_found}.html.erb` sind hier entstanden; der
  Nachweis dazu liegt in `docs/fehlerbehandlung.md` (ab jetzt gepflegt, die
  Q3-Konflikte kommen in Aufgabe 6 dazu).
- Das Löschen eines Kontos hat einen eigenen Bestätigungsschritt bekommen
  (`confirm_destroy`): Die Übersicht verlinkt nur (GET) auf eine Seite, welche
  die Folgen benennt; gelöscht wird erst durch das Formular dort. Die erste
  Stufe wirkt serverseitig, `data-turbo-confirm` kommt als zweites Netz dazu.
- Dabei aufgefallen und behoben: `config/importmap.rb` und
  `app/javascript/application.js` fehlten seit Aufgabe 0, die Importmap war leer
  («imports»: {}) und die Applikation lud **kein** JavaScript. Turbo war damit
  nie aktiv, obwohl README und Plan es voraussetzen (422-Antworten bei
  Formularfehlern, `data-turbo-confirm`). Beide Dateien sind wiederhergestellt,
  Turbo wird geladen; Stimulus bleibt vorerst ungenutzt.

---

## Aufgabe 5: Benutzerrollen und Berechtigungen (Tag 4)

Ziel: Alle Zugriffe der App über Policies; Berechtigungsmatrix aus 4.3.

Policies in `app/policies/` (jede behandelt `user.nil?` = Gast):

| Policy | Regeln |
| --- | --- |
| `ProductPolicy` | `index?/show?` alle (gesperrte Produkte: `show?` nur Moderator/Admin); `new?/create?` angemeldet; `edit?/update?/lock?/unlock?` Moderator/Admin. `Scope`: Gäste/Benutzer sehen `visible`, Moderatoren alles. |
| `RatingPolicy` | `create?` angemeldet und Produkt nicht gesperrt; `edit?/update?/destroy?` nur `record.user == user`; `block?` Moderator/Admin. |
| `ReportPolicy` | `new?/create?` angemeldet, nicht eigene Bewertung, nicht bereits gemeldet; `index?/claim?` Moderator/Admin; `show?/release?/block?/unclaim?` nur `record.moderator == user`. |
| `UserPolicy` | aus Aufgabe 4, erweitert um `Scope`. |
| `ActivityPolicy` (Headless) | `index?` Moderator/Admin (Aufgabe 7). |

- `ApplicationController`: `after_action :verify_authorized, except: :index`
  und `verify_policy_scoped, only: :index` – jede Action muss `authorize`
  aufrufen; vergessene Prüfungen fallen sofort auf.
- Views verwenden `policy(record).action?` für Buttons (Screens 3, 7, 9); die
  Serverprüfung bleibt in den Controllern.

**Verifikation:** `test/policies/*_policy_test.rb` – pro Rolle (Gast, Benutzer,
Moderator, Administrator) mindestens ein erlaubter und ein verweigerter Zugriff
(Q2). Commit.

---

## Aufgabe 6: Kernfunktion (Tag 4)

Ziel: F2–F8 gemäss Breadboards 2–8 und Screens 1, 3–9, mit Locking und
Transaktionen aus 4.4.

### Routen

```ruby
root "products#index"
resources :products, only: [:index, :show, :new, :create, :edit, :update] do
  member { patch :lock; patch :unlock }
  resources :ratings, only: [:create], shallow: true
end
resources :ratings, only: [:edit, :update, :destroy] do
  resources :reports, only: [:new, :create], shallow: true
end
namespace :moderation do
  resources :reports, only: [:index, :show] do
    member { patch :claim; patch :unclaim; patch :release; patch :block }
  end
end
```

### Produkte (`ProductsController`)

- `index`: `policy_scope(Product).search(params[:q]).where(category/chain
  filters).includes(:category, :retail_chain).order(:name)`; Filter-Sidebar
  (Screen 1).
- `show`: Produkt, `stars_distribution`, `ratings.active.includes(:user)`,
  eigene Bewertung (`Current.user&.ratings&.find_by(product:)`) → Formular
  oder Bearbeiten/Löschen (Varianten Screen 3).
- `create`: `Product.transaction { product.save! }`;
  `rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid` →
  bestehendes Produkt via normalisierte Felder suchen, `flash.now[:alert]` mit
  Link darauf, `render :new, status: :unprocessable_entity` (Eingaben bleiben,
  Screen 5). Beide Fehler landen im selben Pfad: Validierung fängt den
  Normalfall, der Index den Gleichzeitigkeitsfall.
- `update` (Moderator): `hidden_field :lock_version`;
  `rescue ActiveRecord::StaleObjectError` → Produkt neu laden, aktuelle Werte
  neben den eigenen Eingaben zeigen, Meldung in Alltagssprache, 422 (Screen 9).
- `lock`/`unlock`: `Product.transaction { product.update!(locked_at: Time.current);
  product.ratings.update_all(status: :gesperrt) ... }` – oder Bewertungen
  bleiben `aktiv`, werden aber über `product.locked?` ausgeblendet. Entscheidung:
  Bewertungen bleiben unverändert, die Sichtbarkeit hängt am Produkt (einfacher,
  reversibel beim Entsperren). Die Transaktion umfasst Produkt + PaperTrail-Version.

### Bewertungen (`RatingsController`) – Kern

Fachlogik in `app/models/rating.rb` als Klassen-/Instanzmethoden, nicht im
Controller:

```ruby
# Rating.submit!(user:, product_id:, attrs)  → Rating oder raise
Product.transaction do                      # BEGIN IMMEDIATE unter SQLite
  product = Product.lock.find(product_id)   # innerhalb der Transaktion laden
  raise Rating::ProductLocked if product.locked?
  rating = product.ratings.create!(user:, **attrs)   # Unique-Index greift hier
  product.update_columns(ratings_count: +1, ratings_sum: +stars)  # bzw. recalculate_aggregates!
end
```

- `Product#recalculate_aggregates!` = `update_columns(ratings_count:
  ratings.active.count, ratings_sum: ratings.active.sum(:stars))` – robust,
  wird bei create/update/destroy/block innerhalb derselben Transaktion
  aufgerufen (Q1: Anzahl und Durchschnitt entsprechen immer den Bewertungen).
- `create`: `rescue ActiveRecord::RecordNotUnique` (paralleler Doppelrequest)
  **und** Validierungsfehler «bereits bewertet» → `redirect_to
  edit_rating_path(existing, rating: { stars:, comment: })` mit
  `flash[:notice]` («Du hast dieses Produkt bereits bewertet…»); `edit` füllt
  die mitgegebenen Werte vor (Screen 4). `ProductLocked` → Produkt mit Meldung.
  Sterne fehlen → 422 auf `products#show`.
- `update`/`destroy`: `authorize @rating` (nur Eigentümer), Transaktion mit
  `recalculate_aggregates!`.

### Meldungen (`ReportsController`, `Moderation::ReportsController`)

- `new/create`: Grund als Radio (Screen 6); doppelte Meldung/eigene Bewertung
  → Meldung, zurück zum Produkt.
- `index`: drei Listen (offen / von mir / von anderen, ausgegraut, Screen 7).
- `claim`: `Report.transaction { report = Report.lock.find(id);
  raise AlreadyClaimed if report.moderator_id.present?;
  report.update!(moderator: Current.user, claimed_at: Time.current, status:
  :in_bearbeitung) }` – pessimistische Sperre; Verlierer sieht «bereits
  übernommen von …» und bleibt auf der Liste.
- `release`/`block`: nur eigener Moderator (Policy), `block` setzt
  `rating.status = gesperrt` + `product.recalculate_aggregates!` + `report`
  entschieden in einer Transaktion (Screen 8). `unclaim` gibt frei.

### Views

Screens 1, 3–9 als ERB gemäss 4.7; Partials `products/_product`,
`ratings/_rating`, `ratings/_form`, `shared/_stars` (★☆-Anzeige), `shared/_flash`.

**Verifikation (Q3-Fälle einzeln nachweisen):**

- Doppelbewertung: zweiter `post product_ratings_path` → Redirect auf `edit`,
  genau eine Bewertung, Eingaben im Formular.
- Duplikat beim Erfassen: 422, Link auf bestehendes Produkt, Eingaben erhalten;
  `RecordNotUnique` per `Product.insert_all` simuliert.
- Konkurrierende Bearbeitung: zwei `open_session`, veraltete `lock_version` →
  422 mit Meldung, erste Änderung bleibt.
- Aggregate: 50 Bewertungen sequenziell (+ Threads-Variante mit Datei-DB
  optional) → `ratings_count == 50`, `ratings_sum` stimmt; nach Löschen/
  Sperren neu korrekt.
- Meldung: zweiter `claim` → abgewiesen, `moderator_id` unverändert; fremder
  Moderator auf `release` → 403.
- Manuell: zwei Browser (normal + Inkognito) für Demo. Commit.

---

## Aufgabe 7: Aktivitätsprotokoll (Tag 4)

- `gem "paper_trail"`, `bin/rails g paper_trail:install`, migrieren.
- `has_paper_trail` in `Product`, `Rating`, `Report` (bei `Rating` `comment`
  ignorieren? Nein – Änderungen am Kommentar sind relevant; Passwörter sind
  nicht betroffen, da `User` nicht versioniert wird).
- `ApplicationController`: `before_action :set_paper_trail_whodunnit`,
  `def user_for_paper_trail = Current.user&.id`.
- Versionen entstehen innerhalb der bestehenden Transaktionen (Aufgabe 6),
  d. h. Bewertung + Aggregat + Aktivitätseintrag sind eine Einheit.
- `ActivitiesController#index` (`/activities`, `ActivityPolicy`: Moderator/
  Admin): `PaperTrail::Version.includes(:item).order(created_at: :desc).limit(100)`,
  Zeile: Zeitpunkt, Akteur (`User.find_by(id: whodunnit)`), Ereignis, Objekt,
  geänderte Felder (`version.changeset` bei `object_changes`).
- Auf der Produktseite für Moderatoren: «Verlauf» mit den Versionen des Produkts.
- ERM 4.5: `VERSION` ist bereits enthalten – Spalten mit der tatsächlichen
  PaperTrail-Migration abgleichen (`object_changes` ergänzen).

**Verifikation:** Test: erfolgreiche Bewertung erzeugt genau eine Version mit
`whodunnit == user.id`; fehlgeschlagene Bewertung (gesperrtes Produkt) erzeugt
keine; Benutzer auf `/activities` → 403. Commit.

---

## Aufgabe 8: Testing (Tag 4)

Ziel: Q2, Q3, Q5 nachweisen; alle Tests grün, < 60 s; Nachweis in `docs/`.

### Fixtures (`test/fixtures/`)

- `users.yml`: `anna` (benutzer), `ben` (benutzer), `moni` (moderator),
  `max` (moderator), `admin` (administrator), `locked` (gesperrt);
  `password_digest: <%= BCrypt::Password.create("probiert-test-2026") %>`.
- `categories.yml`, `retail_chains.yml`, `products.yml` (`hummus` mit
  Aggregaten passend zu den Ratings, `locked_product`), `ratings.yml`
  (`anna_hummus`, `ben_hummus`), `reports.yml` (`open`, `claimed_by_max`).
- `test/test_helper.rb`: `sign_in_as(user)` (POST `session_path`), Fixtures
  `:all`, `parallelize(workers: :number_of_processors)`.

### Testdateien (Zuordnung Klasse → Datei)

| Datei | Prüft |
| --- | --- |
| `test/models/user_test.rb` | Passwortlänge, E-Mail-Normalisierung/Eindeutigkeit, Rollen-Default |
| `test/models/product_test.rb` | Normalisierung, Duplikat-Validierung, `RecordNotUnique` per `insert_all`, `average_rating`, `recalculate_aggregates!` |
| `test/models/rating_test.rb` | Sterne 1–5, eine Bewertung pro User/Produkt, gesperrtes Produkt, Aggregate nach create/update/destroy, 50 Bewertungen |
| `test/models/report_test.rb` | eigene Bewertung nicht meldbar, `claim` nur einmal |
| `test/policies/*_policy_test.rb` | Matrix 4.3 – pro Rolle erlaubt + verweigert |
| `test/controllers/sessions_controller_test.rb`, `registrations_…` | F1, gleiche Fehlermeldung, gesperrtes Konto |
| `test/controllers/products_controller_test.rb` | Suche/Filter, Duplikat 422 mit Link, StaleObjectError via `open_session`, Gast sieht gesperrtes Produkt nicht (404), lock/unlock nur Moderator |
| `test/controllers/ratings_controller_test.rb` | Erfolg + Bestätigung, Doppelbewertung → edit mit Werten, fremde Bewertung ändern/löschen → 403 und unverändert, manipulierte `user_id` ignoriert, Aktivität erzeugt |
| `test/controllers/reports_controller_test.rb`, `moderation/reports_…` | melden, doppelt melden, claim-Konflikt, release/block nur Eigentümer, Benutzer → 403 |
| `test/controllers/admin/users_controller_test.rb` | Rollen, Sperren, Selbstschutz |

### Aussagekraft und Nachweis

- Gemäss Aufgabe 8.4: gezielt einen Fehler einbauen (z. B. `RatingPolicy#destroy?`
  → `true`), vorhersagen, welcher Test scheitert, ausführen, zurückbauen.
- `docs/testing.md`: Tabelle Anforderung (F/Q) → Test → Ergebnis, Laufzeit der
  Suite, Beschreibung des Aussagekraft-Checks. `docs/projektantrag.md` um
  Abschnitt «6. Umsetzung und Prüfung» ergänzen (erreichter Stand, Abweichungen,
  offene Punkte, Verweis auf `docs/testing.md`).
- Q4: `SEED_PRODUCTS=5000 bin/rails db:seed` + `bin/rails runner
  script/search_benchmark.rb` (10 Threads, 95. Perzentil) – Ergebnis in
  `docs/testing.md`.

**Verifikation:** `bin/rails test` grün, Laufzeit < 60 s; keine `skip`.

---

## Querschnitt: Fehlerbehandlung und User Feedback

Eigenes Bewertungskriterium, umgesetzt verteilt über die Aufgaben 4–6 – hier
zusammengezogen, damit nichts durchfällt. Die Wegleitung verlangt: ungültige
Eingaben, fehlende Berechtigungen und konkurrierende Änderungen werden
serverseitig behandelt und verständlich erklärt, Eingaben bleiben soweit möglich
erhalten, die nächste mögliche Handlung ist erkennbar, erfolgreiche Aktionen
werden bestätigt, technische Fehlermeldungen erscheinen nie ungefiltert.

- **Verboten (403)**: `rescue_from Pundit::NotAuthorizedError` →
  `render "errors/forbidden", status: :forbidden` (Aufgabe 4). Keine Umleitung,
  keine ausgeblendeten Buttons als Ersatz (Q2).
- **Nicht gefunden (404)**: `rescue_from ActiveRecord::RecordNotFound` →
  `render "errors/not_found", status: :not_found` mit Weg zurück zur
  Produktsuche. Betrifft gelöschte Bewertungen, gesperrte Produkte für Gäste
  (`policy_scope`) und geratene IDs.
- **Statische Fehlerseiten auf Deutsch**: `public/404.html`, `422.html`,
  `500.html`, `400.html`, `406-unsupported-browser.html` sind noch die
  englischen Rails-Vorlagen («The page you were looking for doesn't exist») –
  übersetzen und optisch an das Layout angleichen. Sie greifen in Produktion
  und wenn der Request den Controller gar nicht erreicht.
- **Formularfehler**: immer `render … status: :unprocessable_entity` mit
  `shared/_errors`; Eingaben bleiben im Formular stehen. Nie `redirect_to` nach
  einem Validierungsfehler – dabei gingen die Eingaben verloren.
- **Konflikte** (Q3, Aufgabe 6): Doppelbewertung → Weiterleitung auf die
  eigene Bewertung mit vorbefüllten Werten; Produkt-Duplikat → 422 mit Link auf
  das bestehende Produkt; veraltete `lock_version` → 422 mit aktuellen Werten
  neben den eigenen Eingaben; bereits übernommene Meldung → Hinweis, wer sie
  bearbeitet.
- **Erfolg bestätigen**: jede schreibende Aktion endet mit `flash[:notice]` in
  Alltagssprache (Muster aus `config/locales/de.yml`, Abschnitt `auth`/
  `profiles`).
- **Keine technischen Details**: keine Exception-Klassen, SQL-Fragmente oder
  Stacktraces im UI; `config.consider_all_requests_local = false` in Produktion
  prüfen.

**Nachweis:** `docs/fehlerbehandlung.md` mit einer Tabelle je Fehlerfall:
Auslöser → Statuscode → Meldung im Klartext → bleiben die Eingaben erhalten? →
nächste mögliche Handlung → absichernder Test. Die Spalten entsprechen genau den
Anforderungen der Wegleitung, damit sich das Kriterium Zeile für Zeile belegen
lässt. Verlinkt aus `README.md` und `docs/projektantrag.md`.

---

## Abschluss (vor Tag 5, gehört zu keiner Aufgabe)

- `README.md` gemäss Wegleitung: Kurzbeschreibung, Stack mit Versionen,
  Voraussetzungen (mise, Ruby 4.0.6, Rails 8.1.3.1, SQLite3), Installation
  (`mise trust && mise install && bundle install`), `bin/rails db:setup`,
  `bin/rails server`, `bin/rails test`, Demo-Konten mit Rollen, Link auf
  `docs/`. Mit frischem Clone durchspielen.
- `CLAUDE.md` aktualisieren (App existiert; Abschnitt «Current state» ersetzen).
- `docs/projektantrag.md` 4.5 an Generator anpassen (siehe Kontext), Bilder
  (`docs/images/ERM.png`) einbinden.

### Glossar der Fachbegriffe

Bewertungskriterium «domänenspezifische Fachbegriffe verwendet» und Vorgabe der
Wegleitung «einheitliche Verwendung von Fachbegriffen». Die Doku ist deutsch,
die Klassennamen sind englisch (Rails-Konvention) – ohne Glossar wirkt das wie
eine Inkonsistenz, mit Glossar ist es eine dokumentierte Entscheidung.

Tabelle in `docs/projektantrag.md` (neuer Abschnitt nach 4.5): Fachbegriff →
Klasse/Spalte im Code → Definition in einem Satz. Mindestens:

| Fachbegriff | Code | Definition |
| --- | --- | --- |
| Produkt | `Product` | Katalogeintrag einer Handelskette |
| Bewertung | `Rating` | 1–5 Sterne mit optionalem Kommentar |
| Meldung | `Report` | Hinweis auf eine unpassende Bewertung |
| Handelskette | `RetailChain` | Migros, Coop, Aldi, Lidl … |
| Kategorie | `Category` | Produktgruppe |
| Benutzer / Moderator / Administrator | `User#role` | die drei Rollen aus 4.3 |
| Gesperrt (Produkt / Bewertung / Konto) | `locked_at` / `status` / `locked_at` | drei verschiedene Sperren – im Glossar auseinanderhalten |

Anschliessend die Doku gegenlesen: dieselbe Sache überall gleich benennen
(nicht einmal «Rezension», einmal «Bewertung»).

### Abgabe zusammenstellen

Gemäss Wegleitung, Abschnitt «Abgabe» – auf Moodle als `mahmud-bawan.zip` mit:

- `mahmud-bawan_dokumentation.pdf` – **PDF-Export der Markdown-Doku**. Eigener
  Arbeitsschritt: Mermaid-Diagramme (ERM 4.5) müssen als Bild im PDF landen,
  nicht als Code-Block; Titelblatt mit Modulname, Datum (TT.MM.JJJJ), Vor- und
  Nachname, Schulklasse steht bereits oben in `projektantrag.md` – Datum auf
  den Abgabetag setzen. Vor dem Export Rechtschreibung prüfen.
- `mahmud-bawan_praesentation.pdf` – separat, hier nicht geplant.
- `mahmud-bawan_code.zip` – Source Code inklusive `README.md`, `test/` und
  `docs/` samt Bildern; `storage/*.sqlite3`, `log/` und `tmp/` vorher entfernen.

Letzter Durchgang vor dem Packen:

- Doku-Abgleich: ERM, Rollen-Matrix und Locking-Konzept gegen den Code prüfen –
  die Wegleitung verlangt, dass die Applikation der Dokumentation entspricht.
  Abweichungen begründen statt stillschweigend lassen (Muster: die Nachträge zu
  Aufgabe 1).
- `bin/rails test`, `bin/rubocop`, `bin/brakeman` grün; frischer Clone nach
  `README.md` aufgesetzt und gestartet.

## Kritische Dateien

`Gemfile`, `config/routes.rb`, `app/controllers/application_controller.rb`,
`app/controllers/concerns/authentication.rb` (generiert),
`app/models/{user,product,rating,report}.rb`, `app/policies/*.rb`,
`app/controllers/{products,ratings,reports}_controller.rb`,
`app/controllers/moderation/reports_controller.rb`,
`app/controllers/admin/users_controller.rb`, `db/seeds.rb`,
`app/views/errors/{forbidden,not_found}.html.erb`, `public/{404,422,500}.html`,
`test/test_helper.rb`, `test/fixtures/*.yml`, `docs/projektantrag.md`,
`docs/testing.md`, `docs/fehlerbehandlung.md`, `README.md`.
