class Category < ApplicationRecord
  include Normalization

  has_many :products, dependent: :restrict_with_error

  normalizes :name, with: ->(n) { n.squish }

  before_validation :set_name_normalized

  validates :name, presence: true, length: { maximum: 60 }
  # Freundliche Meldung im Normalfall; der Unique-Index auf name_normalized
  # weist «Aufstriche» und «AUFSTRICHE» auch bei parallelen Requests ab.
  validates :name_normalized, uniqueness: { message: :already_exists }

  scope :sorted, -> { order(:name) }

  private

  def set_name_normalized
    self.name_normalized = self.class.normalize(name)
  end
end
