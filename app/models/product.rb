class Product < ApplicationRecord
  belongs_to :category
  belongs_to :retail_chain
  belongs_to :created_by, class_name: "User", inverse_of: :products
  has_many :ratings, dependent: :destroy

  normalizes :name, :brand, with: ->(v) { v.squish }

  before_validation :set_normalized_fields

  validates :name, :brand, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 1000 }
  # Freundliche Meldung im Normalfall; bei gleichzeitigen Requests greift der Unique-Index
  validates :name_normalized, uniqueness: {
    scope: [ :brand_normalized, :retail_chain_id ],
    message: :already_exists
  }

  scope :visible, -> { where(locked_at: nil) }
  scope :sorted, -> { order(:name, :brand) }
  scope :search, ->(query) {
    term = self.normalize(query)
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term)}%"
    where("products.name_normalized LIKE :p OR products.brand_normalized LIKE :p", p: pattern)
  }

  # Einheitliche Normalisierung für Duplikatprüfung und Suche
  def self.normalize(value)
    value.to_s.unicode_normalize(:nfkc).downcase.squish
  end

  # Das bereits vorhandene Produkt mit derselben Identität (für den Duplikat-Hinweis)
  def existing_duplicate
    return nil if name_normalized.blank? || brand_normalized.blank? || retail_chain_id.nil?

    Product.where(name_normalized:, brand_normalized:, retail_chain_id:).where.not(id:).first
  end

  def locked?
    locked_at.present?
  end

  def average_rating
    return nil if ratings_count.zero?

    ratings_sum.fdiv(ratings_count)
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
