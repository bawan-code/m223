class Category < ApplicationRecord
  has_many :products, dependent: :restrict_with_error

  normalizes :name, with: ->(n) { n.squish }

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 60 }

  scope :sorted, -> { order(:name) }
end
