require "test_helper"

class Moderation::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @open = reports(:open)               # frei, betrifft ben_hummus
    @claimed = reports(:claimed_by_max)  # von max übernommen, betrifft anna_pesto
  end

  # Zugriff

  test "Gast und Benutzer kommen nicht an die Meldungen" do
    get moderation_reports_path
    assert_redirected_to new_session_path

    sign_in_as users(:anna)
    get moderation_reports_path
    assert_response :forbidden

    patch claim_moderation_report_path(@open)
    assert_response :forbidden
    assert_nil @open.reload.moderator_id
  end

  test "Moderatoren sehen offene, eigene und fremde Meldungen getrennt" do
    sign_in_as users(:moni)

    get moderation_reports_path

    assert_response :success
    assert_select "h2", text: "Offen"
    assert_select "h2", text: "Von anderen übernommen"
    # Die von max übernommene Meldung ist sichtbar, aber ohne Schaltfläche
    assert_select "a[href=?]", moderation_report_path(@claimed), false
    assert_select "form[action=?]", claim_moderation_report_path(@open)
  end

  # Übernehmen – pessimistische Sperre

  test "Übernehmen weist die Meldung genau einer Moderatorin zu" do
    sign_in_as users(:moni)

    patch claim_moderation_report_path(@open)

    @open.reload
    assert_equal users(:moni), @open.moderator
    assert_predicate @open, :in_bearbeitung?
    assert_not_nil @open.claimed_at
    assert_redirected_to moderation_report_path(@open)
  end

  test "wer zu spät kommt, sieht wer schneller war und die Zuordnung bleibt" do
    moni = open_session
    moni.post session_path, params: { email_address: "moni@example.test", password: "probiert-test-2026" }
    max = open_session
    max.post session_path, params: { email_address: "max@example.test", password: "probiert-test-2026" }

    moni.patch claim_moderation_report_path(@open)
    assert_equal users(:moni), @open.reload.moderator

    max.patch claim_moderation_report_path(@open)

    max.follow_redirect!
    assert_match(/inzwischen von Moni Steiner übernommen/, max.response.body)
    assert_equal users(:moni), @open.reload.moderator, "die erste Zuordnung bleibt"
  end

  # Entscheiden – nur die übernehmende Person

  test "eine fremde Moderatorin kommt an die übernommene Meldung nicht heran" do
    sign_in_as users(:moni)

    get moderation_report_path(@claimed)
    assert_response :forbidden

    patch release_moderation_report_path(@claimed)
    assert_response :forbidden

    patch block_moderation_report_path(@claimed)
    assert_response :forbidden

    assert_predicate @claimed.reload, :in_bearbeitung?
    assert_predicate ratings(:anna_pesto).reload, :aktiv?
  end

  test "auch Administratoren entscheiden keine fremde Meldung" do
    sign_in_as users(:admin)

    patch release_moderation_report_path(@claimed)

    assert_response :forbidden
  end

  test "Freigeben lässt die Bewertung stehen" do
    sign_in_as users(:max)

    patch release_moderation_report_path(@claimed)

    assert_predicate @claimed.reload, :freigegeben?
    assert_not_nil @claimed.decided_at
    assert_predicate ratings(:anna_pesto).reload, :aktiv?
  end

  test "Sperren blendet die Bewertung aus und nimmt sie aus dem Durchschnitt" do
    pesto = products(:pesto)
    assert_equal 1, pesto.ratings_count

    sign_in_as users(:max)

    patch block_moderation_report_path(@claimed)

    assert_predicate @claimed.reload, :gesperrt?
    assert_predicate ratings(:anna_pesto).reload, :gesperrt?

    pesto.reload
    assert_equal 0, pesto.ratings_count
    assert_equal 0, pesto.ratings_sum
    assert_nil pesto.average_rating
  end

  test "eine gesperrte Bewertung verschwindet von der Produktseite" do
    sign_in_as users(:max)
    patch block_moderation_report_path(@claimed)
    sign_out

    get product_path(products(:pesto))

    assert_response :success
    assert_select ".rating", 0
  end

  test "Zurückgeben macht die Meldung wieder frei" do
    sign_in_as users(:max)

    patch unclaim_moderation_report_path(@claimed)

    @claimed.reload
    assert_nil @claimed.moderator_id
    assert_predicate @claimed, :offen?
  end
end
