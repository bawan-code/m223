class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Q2: fehlende Berechtigung ist ein serverseitiger 403 – keine Umleitung und
  # kein bloss ausgeblendeter Button.
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  # Gelöschte oder nicht sichtbare Datensätze (auch geratene IDs) enden in einer
  # verständlichen Seite statt in einer technischen Fehlermeldung.
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  private

  # Pundit arbeitet mit dem angemeldeten Benutzer; bei Gästen ist das nil.
  def pundit_user
    current_user
  end

  def forbidden
    render "errors/forbidden", status: :forbidden
  end

  def not_found
    render "errors/not_found", status: :not_found
  end
end
