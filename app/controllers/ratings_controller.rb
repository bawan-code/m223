class RatingsController < ApplicationController
  before_action :set_product, only: :create
  before_action :set_rating, only: %i[ edit update destroy confirm_destroy ]

  # Beim Abgeben ist die einzige mögliche Ablehnung durch die Policy das
  # gesperrte Produkt – ein Zustand, den der Benutzer versteht und der eintreten
  # kann, während sein Formular offen steht. Dafür eine Erklärung statt der
  # 403-Seite; jede andere Ablehnung (fremde Bewertung ändern) bleibt ein 403.
  rescue_from Pundit::NotAuthorizedError do |error|
    if action_name == "create" && @product&.locked?
      redirect_to @product, alert: t("ratings.product_locked")
    else
      forbidden
    end
  end

  # F3 – Kernfunktion
  def create
    @rating = @product.ratings.new(rating_params.merge(user: Current.user))
    authorize @rating

    Rating.submit!(@rating)
    redirect_to @product, notice: t("ratings.created")
  rescue Rating::ProductLocked
    redirect_to @product, alert: t("ratings.product_locked")
  rescue ActiveRecord::RecordNotUnique
    # Zwei gleichzeitige Requests desselben Benutzers – der Index hat gewonnen.
    redirect_to_existing_rating
  rescue ActiveRecord::RecordInvalid
    return redirect_to_existing_rating if @rating.errors.of_kind?(:user_id, :taken)

    render_product_with_errors
  end

  # F4 (Screen 4)
  def edit
    authorize @rating
    # Werte aus einem abgelehnten Formular übernehmen, damit die Eingaben des
    # Benutzers nach dem Konflikt «bereits bewertet» nicht verloren gehen.
    @rating.assign_attributes(params.expect(rating: [ :stars, :comment ])) if params[:rating]
  end

  def update
    authorize @rating
    @rating.change!(rating_params)
    redirect_to @rating.product, notice: t("ratings.updated")
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  # Löschen ist nicht rückgängig zu machen: eigener Schritt statt eines
  # Browser-Dialogs, der sich nicht gestalten lässt und ohne JavaScript ausfällt.
  def confirm_destroy
    authorize @rating
  end

  def destroy
    authorize @rating
    product = @rating.product
    @rating.withdraw!
    redirect_to product, notice: t("ratings.destroyed")
  end

  private

  def set_product
    @product = Product.find(params[:product_id])
  end

  def set_rating
    @rating = Rating.find(params[:id])
  end

  def rating_params
    params.expect(rating: [ :stars, :comment ])
  end

  # Statt eines zweiten Datensatzes führt der Weg zur bestehenden Bewertung –
  # mit den soeben eingegebenen Werten (Q3, Screen 4).
  def redirect_to_existing_rating
    existing = Current.user.ratings.find_by!(product_id: @product.id)

    redirect_to edit_rating_path(existing, rating: { stars: @rating.stars, comment: @rating.comment }),
                notice: t("ratings.already_rated")
  end

  # Fehlende Sterne: zurück auf die Produktseite, Formular mit Fehlermeldung.
  def render_product_with_errors
    @categories = Category.sorted
    @retail_chains = RetailChain.sorted
    @ratings = policy_scope(@product.ratings).includes(:user).newest_first
    @own_rating = nil

    render "products/show", status: :unprocessable_entity
  end
end
