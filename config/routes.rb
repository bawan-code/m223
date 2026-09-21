Rails.application.routes.draw do
  # Authentifizierung (F1)
  resource :session, only: %i[ new create destroy ]
  resources :passwords, param: :token, only: %i[ new create edit update ]
  get  "signup", to: "registrations#new", as: :signup
  post "signup", to: "registrations#create"

  # Eigenes Profil (Aufgabe 3); keine ID in der URL, immer Current.user
  resource :profile, only: %i[ show ]

  # Platzhalter bis zur Produktsuche (Aufgabe 6: root "products#index")
  root "pages#home"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
