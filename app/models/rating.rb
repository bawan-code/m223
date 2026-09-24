class Rating < ApplicationRecord
  STARS = 1..5

  # Ein gesperrtes Produkt nimmt keine neue Bewertung mehr an.
  ProductLocked = Class.new(StandardError)

  belongs_to :user
  belongs_to :product
  has_many :reports, dependent: :destroy

  # Sterne, Kommentar und Sperrstatus werden vollständig protokolliert –
  # gerade die Änderung eines gemeldeten Kommentars muss nachvollziehbar sein.
  has_paper_trail

  # gesperrt: von einem Moderator nach einer Meldung ausgeblendet
  enum :status, { aktiv: 0, gesperrt: 1 }, default: :aktiv, validate: true

  normalizes :comment, with: ->(c) { c.strip.presence }

  validates :stars, inclusion: { in: STARS }
  validates :comment, length: { maximum: 1000 }
  # Fachregel F3; der Unique-Index (user_id, product_id) sichert sie zusätzlich bei parallelen Requests
  validates :user_id, uniqueness: { scope: :product_id, message: :already_rated }
  validate :product_not_locked, on: :create

  scope :active, -> { aktiv }
  scope :newest_first, -> { order(created_at: :desc) }

  # Kern der Applikation (Q1): Eine Bewertung und die Aggregate ihres Produkts
  # dürfen nie auseinanderlaufen – sonst zeigt die Produktseite einen
  # Durchschnitt, den es so nie gegeben hat. Deshalb läuft jede Änderung durch
  # diesen Block: Produkt **innerhalb** der Transaktion laden, ändern,
  # Aggregate neu berechnen, fertig. Die Transaktion bleibt kurz.
  #
  # Unter SQLite serialisiert bereits `BEGIN IMMEDIATE` die Schreiber, `lock`
  # fügt dort keine Zeilensperre hinzu; sie hält die Absicht fest und wirkt auf
  # anderen Datenbanken als echte Sperre (Projektantrag 4.4).
  def self.with_aggregates(product_id)
    transaction do
      product = Product.lock.find(product_id)
      result = yield product
      product.recalculate_aggregates!
      result
    end
  end

  # F3: Bewertung abgeben. Der Unique-Index (user_id, product_id) weist einen
  # gleichzeitigen zweiten Versuch mit RecordNotUnique ab.
  def self.submit!(rating)
    with_aggregates(rating.product_id) do |product|
      raise ProductLocked if product.locked?

      rating.save!
    end

    rating
  end

  # F4: eigene Bewertung ändern beziehungsweise zurückziehen
  def change!(attributes)
    self.class.with_aggregates(product_id) { update!(attributes) }
  end

  def withdraw!
    self.class.with_aggregates(product_id) { destroy! }
  end

  # F7: von der Moderation gesperrt – zählt nicht mehr zum Durchschnitt
  def block!
    self.class.with_aggregates(product_id) { update!(status: :gesperrt) }
  end

  def unblock!
    self.class.with_aggregates(product_id) { update!(status: :aktiv) }
  end

  private

  def product_not_locked
    errors.add(:product, :locked) if product&.locked?
  end
end
