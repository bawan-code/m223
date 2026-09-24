class User < ApplicationRecord
  PASSWORD_MIN_LENGTH = 12

  has_secure_password
  has_many :sessions, dependent: :destroy
  # Der Katalog gehört der Gemeinschaft: beim Löschen des Kontos bleiben die
  # erfassten Produkte bestehen und verlieren nur den Verweis auf den Ersteller (4.4).
  has_many :products, foreign_key: :created_by_id, inverse_of: :created_by, dependent: :nullify
  has_many :ratings, dependent: :destroy
  has_many :reports, foreign_key: :reporter_id, inverse_of: :reporter, dependent: :destroy
  has_many :moderated_reports, class_name: "Report", foreign_key: :moderator_id,
           inverse_of: :moderator, dependent: :nullify

  # Rollen sind hierarchisch: jede Rolle umfasst die Rechte der vorherigen (siehe Projektantrag 4.3)
  enum :role, { benutzer: 0, moderator: 1, administrator: 2 }, default: :benutzer, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  # presence: ein leeres Feld im Formular bedeutet «keine Adresse vorgemerkt»,
  # nicht eine ungültige Adresse
  normalizes :unconfirmed_email, with: ->(e) { e.strip.downcase.presence }
  normalizes :name, with: ->(n) { n.squish }

  validates :name, presence: true, length: { maximum: 100 }
  validates :email_address, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :unconfirmed_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  # allow_nil: beim Laden eines bestehenden Users ist password nil; beim Setzen muss es lang genug sein
  validates :password, length: { minimum: PASSWORD_MIN_LENGTH }, allow_nil: true

  # Anzeigename der Rolle aus den Übersetzungen
  def role_name
    self.class.human_attribute_name("roles.#{role}")
  end

  def moderator_or_admin?
    moderator? || administrator?
  end

  def locked?
    locked_at.present?
  end
end
