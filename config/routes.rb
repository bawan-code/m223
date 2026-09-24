Rails.application.routes.draw do
  # Authentifizierung (F1)
  resource :session, only: %i[ new create destroy ]
  resources :passwords, param: :token, only: %i[ new create edit update ]
  get  "signup", to: "registrations#new", as: :signup
  post "signup", to: "registrations#create"

  # Eigenes Profil (F1); keine ID in der URL – es gibt keine Route auf ein fremdes Profil
  resource :profile, only: %i[ show edit update ]
  resource :password_change, only: %i[ edit update ]
  resource :email_change, only: %i[ new create ]
  # Bestätigungslink aus der Mail: der signierte Token identifiziert das Konto,
  # deshalb auch ohne Anmeldung erreichbar (wie beim Passwort-Reset)
  get "email_confirmations/:token", to: "email_confirmations#show", as: :email_confirmation

  # Benutzerverwaltung, nur für Administratoren (UserPolicy)
  namespace :admin do
    resources :users, only: %i[ index edit update destroy ] do
      member do
        # Zwischenschritt vor dem Löschen: ein Klick in der Übersicht öffnet nur
        # diese Seite, gelöscht wird erst durch das Formular darauf.
        get :confirm_destroy
        patch :lock
        patch :unlock
      end
    end
  end

  # Kernfunktion: Katalog, Bewertungen, Meldungen (F2–F8)
  resources :products, only: %i[ index show new create edit update ] do
    member do
      patch :lock
      patch :unlock
    end
    # Bewertung abgeben immer im Kontext des Produkts; ändern und löschen
    # danach über die Bewertung selbst (shallow).
    resources :ratings, only: %i[ create ]
  end

  resources :ratings, only: %i[ edit update destroy ] do
    # Wie beim Konto: der Klick öffnet nur die Bestätigungsseite, gelöscht wird
    # erst durch das Formular darauf.
    member { get :confirm_destroy }
    resources :reports, only: %i[ new create ]
  end

  # Aktivitätsprotokoll für Moderation und Administration
  resources :activities, only: :index

  namespace :moderation do
    resources :reports, only: %i[ index show ] do
      member do
        patch :claim
        patch :unclaim
        patch :release
        patch :block
      end
    end
  end

  root "products#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
