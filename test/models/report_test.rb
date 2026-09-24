require "test_helper"

class ReportTest < ActiveSupport::TestCase
  test "eine Bewertung kann pro Benutzer nur einmal gemeldet werden" do
    second = Report.new(rating: ratings(:ben_hummus), reporter: users(:anna), reason: :spam)

    assert_not second.valid?
    assert second.errors.of_kind?(:reporter_id, :taken)
  end

  test "die eigene Bewertung kann nicht gemeldet werden" do
    own = Report.new(rating: ratings(:ben_hummus), reporter: users(:ben), reason: :spam)

    assert_not own.valid?
    assert own.errors.added?(:rating, :own_rating)
  end

  test "Grund ist Pflicht" do
    report = Report.new(rating: ratings(:ben_hummus), reporter: users(:moni), reason: nil)

    assert_not report.valid?
    assert report.errors.added?(:reason, :inclusion, value: nil)
  end

  test "ohne gewählten Grund wird die Meldung abgewiesen statt still gesetzt" do
    report = Report.new(rating: ratings(:ben_hummus), reporter: users(:moni))

    assert_nil report.reason, "reason darf keinen Datenbank-Default haben"
    assert_not report.valid?
  end

  test "claimed? und decided? spiegeln den Status" do
    assert_not reports(:open).claimed?
    assert_predicate reports(:claimed_by_max), :claimed?
    assert_not reports(:claimed_by_max).decided?

    reports(:claimed_by_max).update!(status: :freigegeben, decided_at: Time.current)
    assert_predicate reports(:claimed_by_max), :decided?
  end

  test "Scopes für offene und übernommene Meldungen" do
    assert_equal [ reports(:open) ], Report.open_reports.to_a
    assert_equal [ reports(:claimed_by_max) ], Report.claimed_by(users(:max)).to_a
    assert_empty Report.claimed_by(users(:moni))
  end
end
