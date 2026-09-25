module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_user
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    # Auch in öffentlichen Actions verfügbar (dort läuft require_authentication nicht)
    def current_user
      resume_session&.user
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      return unless cookies.signed[:session_id]

      session = Session.includes(:user).find_by(id: cookies.signed[:session_id])
      # Sitzungen gesperrter Konten werden beim Sperren gelöscht; zur Sicherheit hier nochmals prüfen
      session if session && !session.user.locked?
    end

    # Merkt sich, wohin der Benutzer nach der Anmeldung zurück soll: bei GET (und
    # HEAD, das Rails wie GET routet) die Seite selbst, bei schreibenden Aktionen
    # die Seite, von der er kam.
    def request_authentication
      reading = request.get? || request.head?
      session[:return_to_after_authenticating] = reading ? request.url : request.referer
      redirect_to new_session_path, alert: t("auth.required")
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
