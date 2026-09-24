class Report < ApplicationRecord
  belongs_to :rating
  belongs_to :reporter, class_name: "User", inverse_of: :reports
  belongs_to :moderator, class_name: "User", optional: true, inverse_of: :moderated_reports

  # Bewusst ohne Default (auch in der Datenbank): ohne gewählten Grund bleibt
  # reason nil und die Meldung wird abgewiesen, statt still «beleidigend» zu werden.
  enum :reason, { beleidigend: 0, spam: 1, kein_bezug: 2, anderes: 3 }, validate: true
  # offen -> in_bearbeitung (übernommen) -> freigegeben | gesperrt (entschieden)
  enum :status, { offen: 0, in_bearbeitung: 1, freigegeben: 2, gesperrt: 3 }, default: :offen, validate: true

  validates :reporter_id, uniqueness: { scope: :rating_id, message: :already_reported }
  validate :not_own_rating

  scope :open_reports, -> { offen }
  scope :claimed_by, ->(user) { in_bearbeitung.where(moderator: user) }
  scope :newest_first, -> { order(created_at: :desc) }

  def claimed?
    moderator_id.present?
  end

  def decided?
    freigegeben? || gesperrt?
  end

  private

  def not_own_rating
    errors.add(:rating, :own_rating) if rating && reporter && rating.user_id == reporter.id
  end
end
