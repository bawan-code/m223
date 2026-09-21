class Rating < ApplicationRecord
  STARS = 1..5

  belongs_to :user
  belongs_to :product
  has_many :reports, dependent: :destroy

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

  private

  def product_not_locked
    errors.add(:product, :locked) if product&.locked?
  end
end
