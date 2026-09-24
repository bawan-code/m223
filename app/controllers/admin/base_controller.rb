module Admin
  # Gemeinsame Basis des Admin-Bereichs. Die Berechtigung prüft jede Action
  # einzeln über die Policy; `verify_authorized` stellt sicher, dass keine
  # vergessen geht – eine ungeprüfte Action schlägt sofort fehl statt still
  # offen zu stehen.
  class BaseController < ApplicationController
    after_action :verify_authorized
  end
end
