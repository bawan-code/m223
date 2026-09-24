require "test_helper"

class ReportPolicyTest < ActiveSupport::TestCase
  setup do
    @open = reports(:open)                  # noch frei
    @claimed = reports(:claimed_by_max)     # von max übernommen
  end

  def new_report_for(rating, reporter)
    Report.new(rating:, reporter:, reason: :spam)
  end

  # Melden

  test "Gäste dürfen nicht melden" do
    assert_not ReportPolicy.new(nil, new_report_for(ratings(:ben_hummus), nil)).create?
  end

  test "angemeldete Benutzer dürfen eine fremde Bewertung melden" do
    assert ReportPolicy.new(users(:moni), new_report_for(ratings(:ben_hummus), users(:moni))).create?
  end

  test "die eigene Bewertung lässt sich nicht melden" do
    assert_not ReportPolicy.new(users(:ben), new_report_for(ratings(:ben_hummus), users(:ben))).create?
  end

  test "dieselbe Bewertung lässt sich nicht zweimal melden" do
    # anna hat ben_hummus bereits gemeldet (Fixture :open)
    assert_not ReportPolicy.new(users(:anna), new_report_for(ratings(:ben_hummus), users(:anna))).create?
  end

  # Liste

  test "die Meldungsliste sehen nur Moderation und Administration" do
    assert_not ReportPolicy.new(nil, Report).index?
    assert_not ReportPolicy.new(users(:anna), Report).index?
    assert ReportPolicy.new(users(:moni), Report).index?
    assert ReportPolicy.new(users(:admin), Report).index?
  end

  test "der Scope liefert Benutzern und Gästen nichts" do
    assert_empty ReportPolicy::Scope.new(nil, Report).resolve
    assert_empty ReportPolicy::Scope.new(users(:anna), Report).resolve
    assert_equal Report.count, ReportPolicy::Scope.new(users(:moni), Report).resolve.count
  end

  # Übernehmen

  test "eine freie Meldung kann jede Moderatorin übernehmen" do
    assert ReportPolicy.new(users(:moni), @open).claim?
    assert ReportPolicy.new(users(:max), @open).claim?
  end

  test "eine übernommene Meldung kann niemand mehr übernehmen" do
    assert_not ReportPolicy.new(users(:moni), @claimed).claim?
    assert_not ReportPolicy.new(users(:max), @claimed).claim?, "auch die eigene nicht noch einmal"
  end

  test "Benutzer dürfen keine Meldungen übernehmen" do
    assert_not ReportPolicy.new(users(:anna), @open).claim?
  end

  # Entscheiden – nur die übernehmende Person

  test "nur die übernehmende Moderatorin entscheidet die Meldung" do
    assert ReportPolicy.new(users(:max), @claimed).show?
    assert ReportPolicy.new(users(:max), @claimed).release?
    assert ReportPolicy.new(users(:max), @claimed).block?
    assert ReportPolicy.new(users(:max), @claimed).unclaim?
  end

  test "eine fremde Moderatorin kommt an eine übernommene Meldung nicht heran" do
    policy = ReportPolicy.new(users(:moni), @claimed)

    assert_not policy.show?
    assert_not policy.release?
    assert_not policy.block?
    assert_not policy.unclaim?
  end

  test "auch Administratoren entscheiden keine fremde Meldung" do
    assert_not ReportPolicy.new(users(:admin), @claimed).release?
  end

  test "eine noch freie Meldung lässt sich nicht entscheiden" do
    assert_not ReportPolicy.new(users(:moni), @open).show?
    assert_not ReportPolicy.new(users(:moni), @open).block?
  end
end
