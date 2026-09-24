class Report < ApplicationRecord
  # Zwei Moderatoren haben gleichzeitig «Übernehmen» gedrückt; der Verlierer
  # erfährt, wer schneller war.
  class AlreadyClaimed < StandardError
    attr_reader :moderator

    def initialize(moderator)
      @moderator = moderator
      super("Meldung ist bereits übernommen")
    end
  end

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

  # Pessimistische Sperre (Projektantrag 4.4): Die Meldung wird innerhalb der
  # Transaktion neu geladen und nur übernommen, wenn sie dann noch frei ist.
  # Genau eine Moderatorin gewinnt, die andere bleibt auf der Liste.
  def claim!(moderator)
    self.class.transaction do
      fresh = self.class.lock.find(id)
      raise AlreadyClaimed, fresh.moderator if fresh.moderator_id.present?

      fresh.update!(moderator:, claimed_at: Time.current, status: :in_bearbeitung)
      reload
    end
  end

  # Wieder freigeben, ohne zu entscheiden
  def unclaim!
    update!(moderator: nil, claimed_at: nil, status: :offen)
  end

  # Entscheidung: Bewertung bleibt stehen
  def release!
    update!(status: :freigegeben, decided_at: Time.current)
  end

  # Entscheidung: Bewertung wird gesperrt. Sperrung, Aggregate des Produkts und
  # die Entscheidung selbst gehören in eine Transaktion.
  def block!
    self.class.transaction do
      rating.block!
      update!(status: :gesperrt, decided_at: Time.current)
    end
  end

  private

  def not_own_rating
    errors.add(:rating, :own_rating) if rating && reporter && rating.user_id == reporter.id
  end
end
