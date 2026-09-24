require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @foreign = ratings(:ben_hummus)   # von ben
    @own = ratings(:anna_hummus)      # von anna
  end

  test "Gast wird zur Anmeldung geleitet" do
    get new_rating_report_path(@foreign)

    assert_redirected_to new_session_path
  end

  test "eine fremde Bewertung melden" do
    sign_in_as users(:moni)

    get new_rating_report_path(@foreign)
    assert_response :success
    assert_select "input[type=radio][name='report[reason]']", Report.reasons.size

    assert_difference "Report.count", 1 do
      post rating_reports_path(@foreign), params: { report: { reason: "spam" } }
    end

    report = Report.order(:created_at).last
    assert_equal users(:moni), report.reporter
    assert_predicate report, :offen?
    assert_redirected_to @foreign.product
    follow_redirect!
    assert_select ".flash-notice", text: /Moderation/
  end

  test "ohne Grund wird die Meldung abgewiesen" do
    sign_in_as users(:moni)

    assert_no_difference "Report.count" do
      post rating_reports_path(@foreign), params: { report: { reason: "" } }
    end

    assert_response :unprocessable_entity
    assert_select ".errors li", text: /Grund/
  end

  test "die eigene Bewertung lässt sich nicht melden" do
    sign_in_as users(:anna)

    assert_no_difference "Report.count" do
      post rating_reports_path(@own), params: { report: { reason: "spam" } }
    end

    assert_redirected_to @own.product
    follow_redirect!
    assert_select ".flash-alert", text: /eigene Bewertung/
  end

  test "dieselbe Bewertung lässt sich nicht zweimal melden" do
    sign_in_as users(:anna)   # hat ben_hummus bereits gemeldet (Fixture)

    assert_no_difference "Report.count" do
      post rating_reports_path(@foreign), params: { report: { reason: "beleidigend" } }
    end

    follow_redirect!
    assert_select ".flash-alert", text: /bereits gemeldet/
  end

  test "der Melden-Link erscheint nur bei fremden, noch nicht gemeldeten Bewertungen" do
    sign_in_as users(:moni)
    get product_path(products(:hummus))
    assert_select "a[href=?]", new_rating_report_path(@foreign)

    sign_out
    sign_in_as users(:anna)   # hat bereits gemeldet
    get product_path(products(:hummus))
    assert_select "a[href=?]", new_rating_report_path(@foreign), false
  end
end
