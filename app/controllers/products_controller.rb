class ProductsController < ApplicationController
  # Ohne Begrenzung rendert die Liste bei 5'000 Produkten jede Karte einzeln –
  # das kostete im Q4-Benchmark über zwei Sekunden, während die Abfrage selbst
  # unter 100 ms bleibt. Die Seitengrösse hält die Antwortzeit unabhängig von
  # der Katalogrösse.
  PER_PAGE = 12

  allow_unauthenticated_access only: %i[ index show ]
  before_action :set_product, only: %i[ show edit update lock unlock ]
  before_action :load_stammdaten, only: %i[ new create edit update ]

  # F2: suchen und filtern (Screen 1)
  def index
    matches = policy_scope(Product)
                .search(params[:q])
                .in_category(params[:category_id])
                .from_chain(params[:retail_chain_id])

    @total = matches.count
    @page = [ params[:page].to_i, 1 ].max
    @pages = [ (@total / PER_PAGE.to_f).ceil, 1 ].max
    @products = matches.includes(:category, :retail_chain)
                       .sorted(params[:sort])
                       .limit(PER_PAGE)
                       .offset((@page - 1) * PER_PAGE)

    load_stammdaten
  end

  # F5: Durchschnitt, Anzahl, Verteilung und Kommentare (Screen 3)
  def show
    authorize @product
    load_ratings
    # Verlauf nur für die Moderation – dieselbe Regel wie beim Protokoll.
    @versions = @product.versions.reorder(created_at: :desc).limit(10) if policy(:activity).index?
  end

  def new
    @product = Product.new
    authorize @product
  end

  # F6: erfassen. Zwei Wege führen zum selben Ergebnis – die Validierung fängt
  # den Normalfall, der Unique-Index den Gleichzeitigkeitsfall.
  def create
    @product = Product.new(created_by: Current.user)
    authorize @product
    @product.assign_attributes(permitted_attributes(@product))

    Product.transaction { @product.save! }
    redirect_to @product, notice: t("products.created")
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    @existing = @product.existing_duplicate
    render :new, status: :unprocessable_entity
  end

  # F8: Moderation korrigiert Produktdaten (Screen 9)
  def edit
    authorize @product
  end

  def update
    authorize @product
    @product.assign_attributes(permitted_attributes(@product))

    Product.transaction { @product.save! }
    redirect_to @product, notice: t("products.updated")
  rescue ActiveRecord::StaleObjectError
    # Jemand war schneller. Die eigenen Eingaben bleiben stehen, die aktuellen
    # Werte werden daneben gezeigt; die übernommene Version erlaubt den zweiten
    # Versuch, nachdem der Unterschied sichtbar war (Screen 9).
    @current = Product.find(@product.id)
    @product.lock_version = @current.lock_version
    flash.now[:alert] = t("products.stale")
    render :edit, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    @existing = @product.existing_duplicate
    render :edit, status: :unprocessable_entity
  end

  # F8: sperren. Die Bewertungen bleiben unverändert – sichtbar sind sie nur
  # über das Produkt, damit das Entsperren alles wiederherstellt.
  def lock
    authorize @product
    Product.transaction { @product.update!(locked_at: Time.current) }
    redirect_to @product, notice: t("products.locked")
  end

  def unlock
    authorize @product
    Product.transaction { @product.update!(locked_at: nil) }
    redirect_to @product, notice: t("products.unlocked")
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def load_stammdaten
    @categories = Category.sorted
    @retail_chains = RetailChain.sorted
  end

  # Für die Produktseite: sichtbare Bewertungen, die eigene separat – sie soll
  # auch dann erscheinen, wenn sie gesperrt wurde.
  def load_ratings
    @ratings = policy_scope(@product.ratings).includes(:user).newest_first
    @own_rating = Current.user&.ratings&.find_by(product: @product)
    @rating ||= @product.ratings.new
  end
end
