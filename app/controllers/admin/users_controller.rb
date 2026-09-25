module Admin
  class UsersController < BaseController
    before_action :set_user, except: :index

    def index
      authorize User
      @users = policy_scope(User).order(:name)
    end

    def edit
      authorize @user
    end

    def update
      authorize @user

      @user.assign_attributes(permitted_attributes(@user))
      # Eine vom Administrator gesetzte Adresse gilt sofort: Er handelt bewusst,
      # und die Änderung steht im Aktivitätsprotokoll. Eine noch offene
      # Bestätigung des Benutzers wäre danach gegenstandslos.
      @user.unconfirmed_email = nil if @user.email_address_changed?

      if @user.save
        redirect_to admin_users_path, notice: t("admin.users.updated", name: @user.name)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # Sperren beendet auch alle laufenden Sitzungen – sonst bliebe der Benutzer
    # bis zum Ablauf des Cookies angemeldet. Beides gehört in eine Transaktion.
    def lock
      authorize @user

      User.transaction do
        @user.update!(locked_at: Time.current)
        @user.sessions.destroy_all
      end

      redirect_to admin_users_path, notice: t("admin.users.locked", name: @user.name)
    end

    def unlock
      authorize @user

      @user.update!(locked_at: nil)

      redirect_to admin_users_path, notice: t("admin.users.unlocked", name: @user.name)
    end

    # Löschen ist nicht rückgängig zu machen, deshalb ein eigener Schritt: die
    # Übersicht verlinkt nur hierher (GET), gelöscht wird erst durch das
    # Formular auf dieser Seite. Ein verklickter Link löscht damit nichts.
    def confirm_destroy
      authorize @user
    end

    # Konto löschen (Projektantrag 4.4): Konto, Bewertungen und die Aggregate
    # der betroffenen Produkte müssen gemeinsam stimmen. Die Produkte selbst
    # bleiben im Katalog und verlieren nur den Ersteller.
    def destroy
      authorize @user
      name = @user.name

      User.transaction do
        affected_products = Product.where(id: @user.ratings.select(:product_id)).to_a
        @user.destroy!
        affected_products.each(&:recalculate_aggregates!)
      end

      redirect_to admin_users_path, notice: t("admin.users.destroyed", name:)
    end

    private

    def set_user
      @user = User.find(params[:id])
    end
  end
end
