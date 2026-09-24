# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Project repository for **Probiert**, a community product-rating app for Swiss supermarket products (Migros, Coop, Aldi, Lidl …), built as the graded project for ICT Modul 223 "Multiuser-Applikationen objektorientiert realisieren" (class Ina24b, author Bawan Mahmud). Everything is written in German (docs, UI, commit context); keep it that way.

Current state: **Aufgaben 0–4 done** — Rails 8.1.3.1 app in the repo root; all models with validations, unique indexes and German messages (`config/locales/de.yml`); seeds, fixtures, model tests. Authentication complete (F1): `Authentication` concern (`current_user` helper works in public actions too, `return_to` after login, locked accounts rejected), `SessionsController`, `RegistrationsController` (`/signup`), `PasswordsController`, German views, navigation in the layout, `docs/sicherheit.md`. Profile complete: `ProfilesController` (show/edit/update, always `Current.user`, no ID in any route), `PasswordChangesController` (current password required, other sessions terminated), `EmailChangesController` + `EmailConfirmationsController` (`unconfirmed_email` plus `generates_token_for :email_confirmation`, mail sent after commit, link logged — no SMTP), `UserMailer`. Authorization started (F1/Q2): Pundit installed, `ApplicationPolicy` (guests handled, default deny), `UserPolicy` (admin only; self-lock/self-delete/self-demotion blocked via `permitted_attributes`), `Admin::BaseController` (`after_action :verify_authorized`) + `Admin::UsersController` (index/edit/update/lock/unlock/destroy), `rescue_from` for 403 and 404 with `app/views/errors/`. Next is Aufgabe 5 (policies for all remaining areas, global `verify_authorized`/`verify_policy_scoped`). Placeholder `pages#home` root route until Aufgabe 6. The implementation plan is `docs/projektplan.md` (Aufgabe 1–8, in course order); update its progress as tasks complete. Other key files:

- `docs/projektantrag.md` — the project proposal (problem, vision, MVP scope, requirements F1–F12, quality attributes Q1–Q5, roles, locking/transaction concept, ERM, breadboards, screens). This is the spec; read it before implementing anything.
- `ict-modul-223-teilnehmerunterlagen/` — the course materials (a separately cloned git repo, gitignored). Reference only; do not edit. Most useful files: `guides/rails/cheatsheet.md`, `guides/rails/testing-cheatsheet.md`, `guides/rails/authorization.md`, `guides/rails/transactions.md`, `guides/projektarbeit/wegleitung.md` (grading requirements), `guides/projektarbeit/exercises/*.md` (the ordered implementation tasks).

## Required stack (fixed by the course)

- Ruby 4.0.6 (`mise.toml`), Rails 8.1.3.1, SQLite3, Propshaft assets, Minitest (Rails default, not RSpec). `gem "json", "~> 2.0"` is pinned on purpose (JSON 3 breaks this Rails version's cookie handling).
- Authentication via `bin/rails generate authentication` (Rails 8 generator: `User` with `email_address`, `Session` model, `Current.user`, `Authentication` concern, `authenticate_by`) — no Devise; passwords ≥ 12 chars.
- Authorization via **Pundit** policies (`app/policies`), roles as an `ActiveRecord::Enum` on `User` (`benutzer`, `moderator`, `administrator`). Every policy must handle `user == nil` (guest). Forbidden → HTTP 403 page, not a redirect.
- SQLite + Rails 8.1: every transaction starts with `BEGIN IMMEDIATE` (single writer); `lock!` adds no row lock. Load the record *inside* the transaction and keep it short.
- Activity log via PaperTrail or Audited on the core-function records.

## Commands

```sh
bin/rails server                     # dev server on localhost:3000
bin/rails db:setup                   # create + migrate + seed demo data
bin/rails test                       # full suite (must stay green and < 60 s, Q5)
bin/rails test test/models/rating_test.rb          # single file
bin/rails test test/models/rating_test.rb:12       # single test by line
bin/rubocop                          # style (rubocop-rails-omakase; course folder excluded)
bin/rails routes
bin/rails g model Name attr:type ...  # use generators for models/migrations
```

Run `bin/rails test` after every code change and keep it green; never skip or weaken tests.

Tests use `ActiveSupport::TestCase` (models/policies) and `ActionDispatch::IntegrationTest` (controllers), with fixtures in `test/fixtures` (seeds are not used in tests). A `sign_in_as users(:name)` helper belongs in `test/test_helper.rb`. Name tests after the class under test (`RatingTest`, `RatingsControllerTest`, `RatingPolicyTest`) and describe behaviour in the test name.

## Domain architecture (from docs/projektantrag.md)

Core function of MVP iteration 1: **rate a product** (1–5 stars + optional comment) in a community-maintained catalog.

Key invariants the code must enforce — these are what the project is graded on:

- **One active rating per (user, product)**: unique DB index plus model validation. A second attempt redirects to editing the existing rating rather than creating a duplicate.
- **Product aggregates** (`ratings_count`, average) are updated inside a transaction with a row lock on the product (`lock!` / `with_lock`) on every rating create/update/delete — no lost updates under 50 concurrent writes (Q1).
- **Product creation** is guarded by a unique index over normalized (name, brand, retail chain); the losing concurrent insert is rejected and pointed at the existing product.
- **Moderator product edits** use optimistic locking (`lock_version` column).
- **Reports (Meldungen)** are claimed with pessimistic locking; a claimed report is locked for other moderators, and exactly one moderator decides it.
- **Locking a product** and **deleting a user account** are transactions spanning the parent and its ratings.
- Locked products cannot be rated. Unauthenticated visitors are read-only and get redirected to login on any write.
- Every conflict (duplicate rating, duplicate product, stale edit) must produce a plain-language flash message, keep the form input, and link the next possible action (Q3). Forbidden access is a server-side 403 (Q2), never hidden only in the UI.

Roles: Benutzer (rate, create products, report ratings, edit/delete own ratings) < Moderator (+ edit/lock any product, handle reports, lock ratings) < Administrator (+ assign roles, lock accounts, manage categories and chains). Each role needs at least one allowed and one denied access covered by tests.

## Deliverable constraints

- Project documentation lives in `docs/` as Markdown with embedded images (ERM, breadboards, fat-marker sketches), continuing `projektantrag.md`; keep it in sync with the implementation.
- `README.md` must explain how to run: stack with versions, setup, DB setup and seeds, start/test commands, and demo accounts per role. Link to `docs/` instead of repeating it.
