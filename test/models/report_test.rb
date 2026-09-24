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

  # Pessimistische Sperre beim Übernehmen (4.4)

  test "eine Meldung lässt sich nur einmal übernehmen" do
    report = reports(:open)

    report.claim!(users(:moni))

    assert_equal users(:moni), report.reload.moderator
    assert_predicate report, :in_bearbeitung?

    error = assert_raises Report::AlreadyClaimed do
      reports(:open).claim!(users(:max))
    end

    assert_equal users(:moni), error.moderator, "der Verlierer erfährt, wer schneller war"
    assert_equal users(:moni), report.reload.moderator
  end

  test "Zurückgeben macht die Meldung wieder übernehmbar" do
    report = reports(:claimed_by_max)

    report.unclaim!

    assert_nil report.moderator_id
    assert_predicate report, :offen?
    assert_nothing_raised { report.claim!(users(:moni)) }
  end

  test "Freigeben lässt die Bewertung unverändert" do
    report = reports(:claimed_by_max)

    report.release!

    assert_predicate report, :freigegeben?
    assert_not_nil report.decided_at
    assert_predicate ratings(:anna_pesto).reload, :aktiv?
  end

  test "Sperren entscheidet die Meldung und nimmt die Bewertung aus dem Durchschnitt" do
    report = reports(:claimed_by_max)
    product = products(:pesto)

    report.block!

    assert_predicate report, :gesperrt?
    assert_not_nil report.decided_at
    assert_predicate ratings(:anna_pesto).reload, :gesperrt?
    assert_equal 0, product.reload.ratings_count
    assert_equal 0, product.ratings_sum
  end

  test "Scopes für offene und übernommene Meldungen" do
    assert_equal [ reports(:open) ], Report.open_reports.to_a
    assert_equal [ reports(:claimed_by_max) ], Report.claimed_by(users(:max)).to_a
    assert_empty Report.claimed_by(users(:moni))
  end
end
