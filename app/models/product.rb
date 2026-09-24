class Product < ApplicationRecord
  include Normalization

  belongs_to :category
  belongs_to :retail_chain
  # optional, weil ein gelöschtes Konto seine Produkte im Katalog zurücklässt (4.4);
  # beim Erfassen ist der Ersteller weiterhin Pflicht.
  belongs_to :created_by, class_name: "User", inverse_of: :products, optional: true
  has_many :ratings, dependent: :destroy

  # Aktivitätsprotokoll (F-Anforderung «Nachvollziehbarkeit»). Die Aggregate
  # sind abgeleitete Werte und werden ohnehin per update_columns geschrieben;
  # `ignore` hält sie zusätzlich aus dem Protokoll, damit dort nur echte
  # redaktionelle Änderungen stehen. lock_version ist reine Mechanik.
  # `skip`: die normalisierten Spalten sind aus Bezeichnung und Marke abgeleitet
  # und erschienen im Protokoll sonst als zweite, gleichlautende Zeile.
  has_paper_trail ignore: %i[ ratings_count ratings_sum lock_version ],
                  skip: %i[ name_normalized brand_normalized ]

  normalizes :name, :brand, with: ->(v) { v.squish }

  before_validation :set_normalized_fields

  validates :name, :brand, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 1000 }
  validates :created_by, presence: true, on: :create
  # Freundliche Meldung im Normalfall; bei gleichzeitigen Requests greift der Unique-Index
  validates :name_normalized, uniqueness: {
    scope: [ :brand_normalized, :retail_chain_id ],
    message: :already_exists
  }

  scope :visible, -> { where(locked_at: nil) }
  # Filter der Produktsuche (Screen 1): ein leerer Filter schränkt nicht ein.
  scope :in_category, ->(id) { id.present? ? where(category_id: id) : all }
  scope :from_chain, ->(id) { id.present? ? where(retail_chain_id: id) : all }
  # Sortierung der Trefferliste (Screen 1); ohne Wahl alphabetisch. Nach
  # Bewertung stehen unbewertete Produkte immer am Schluss – sie sind weder gut
  # noch schlecht bewertet. Bei gleichem Durchschnitt kommt das Produkt mit mehr
  # Bewertungen zuerst, weil sein Durchschnitt belastbarer ist.
  SORTINGS = %w[ beste schlechteste ].freeze
  UNRATED_LAST = Arel.sql("products.ratings_count = 0")
  RATING_AVERAGE = Arel.sql("CAST(products.ratings_sum AS REAL) / NULLIF(products.ratings_count, 0)")

  scope :sorted, ->(sorting = nil) {
    case sorting
    when "beste" then order(UNRATED_LAST, RATING_AVERAGE.desc, ratings_count: :desc, name: :asc, brand: :asc)
    when "schlechteste" then order(UNRATED_LAST, RATING_AVERAGE.asc, ratings_count: :desc, name: :asc, brand: :asc)
    else order(:name, :brand)
    end
  }
  scope :search, ->(query) {
    term = self.normalize(query)
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term)}%"
    where("products.name_normalized LIKE :p OR products.brand_normalized LIKE :p", p: pattern)
  }

  # Das bereits vorhandene Produkt mit derselben Identität (für den
  # Duplikat-Hinweis). Normalisiert selbst, damit die Suche auch dann greift,
  # wenn die Validierung noch nicht gelaufen ist – etwa wenn der Unique-Index
  # zugeschlagen hat, bevor das Modell geprüft wurde.
  def existing_duplicate
    name_key = self.class.normalize(name)
    brand_key = self.class.normalize(brand)
    return nil if name_key.blank? || brand_key.blank? || retail_chain_id.nil?

    Product.where(name_normalized: name_key, brand_normalized: brand_key, retail_chain_id:)
           .where.not(id:).first
  end

  def locked?
    locked_at.present?
  end

  def average_rating
    return nil if ratings_count.zero?

    ratings_sum.fdiv(ratings_count)
  end

  # Ab diesem Durchschnitt trägt ein Produkt das Siegel «Probiert». Gerundet
  # wie in der Anzeige, damit ein angezeigtes «4,0» nie ohne Siegel dasteht.
  CERTIFIED_FROM = 4

  def certified?
    ratings_count.positive? && average_rating.round(1) >= CERTIFIED_FROM
  end

  # Anzahl aktiver Bewertungen je Sternwert, 5..1, fehlende Werte als 0
  def stars_distribution
    counts = ratings.active.group(:stars).count
    (5).downto(1).to_h { |stars| [ stars, counts.fetch(stars, 0) ] }
  end

  # Aggregate aus den aktiven Bewertungen neu berechnen. Wird innerhalb der
  # Transaktion aufgerufen, die die Bewertung ändert (Q1: Anzahl und
  # Durchschnitt entsprechen immer den gespeicherten Bewertungen).
  def recalculate_aggregates!
    active = ratings.active
    update_columns(ratings_count: active.count, ratings_sum: active.sum(:stars).to_i)
  end

  private

  def set_normalized_fields
    self.name_normalized = Product.normalize(name)
    self.brand_normalized = Product.normalize(brand)
  end
end
