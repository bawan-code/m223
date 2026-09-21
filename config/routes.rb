Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Platzhalter bis zur Produktsuche (Aufgabe 6: root "products#index")
  root "pages#home"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
