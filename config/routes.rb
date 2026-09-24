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

  # Platzhalter bis zur Produktsuche (Aufgabe 6: root "products#index")
  root "pages#home"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
