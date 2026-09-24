module Admin
  # Gemeinsame Basis des Admin-Bereichs. Die Berechtigung prüft jede Action
  # einzeln über die Policy; dass keine vergessen geht, erzwingt der
  # ApplicationController mit `verify_authorized` / `verify_policy_scoped`.
  class BaseController < ApplicationController
  end
end
