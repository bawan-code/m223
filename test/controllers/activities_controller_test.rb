require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  test "Gast wird zur Anmeldung geleitet" do
    get activities_path

    assert_redirected_to new_session_path
  end

  test "Benutzer erhalten 403" do
    sign_in_as users(:anna)

    get activities_path

    assert_response :forbidden
  end

  test "Moderatoren sehen die Änderungen mit Akteur, Ereignis und Feldern" do
    sign_in_as users(:anna)
    patch rating_path(ratings(:anna_hummus)), params: { rating: { stars: 1 } }
    sign_out

    sign_in_as users(:moni)
    get activities_path

    assert_response :success
    assert_select "tbody tr", 1
    assert_select "tbody", text: /Anna Keller/
    assert_select "tbody", text: /Geändert/
    assert_select "tbody", text: /Sterne/
  end

  # Der Feed enthält Einträge zu allen drei versionierten Modellen. Bewertungen
  # und Meldungen haben keine eigene Seite – ohne eigenes Linkziel suchte Rails
  # ein `report_path`, das es nicht gibt, und die Seite brach.
  test "der Feed zeigt Produkte, Bewertungen und Meldungen und verlinkt sie aufs Produkt" do
    sign_in_as users(:anna)
    patch rating_path(ratings(:anna_hummus)), params: { rating: { stars: 1 } }
    sign_out

    sign_in_as users(:max)
    patch block_moderation_report_path(reports(:claimed_by_max))
    patch lock_product_path(products(:hummus))

    get activities_path

    assert_response :success
    assert_select "tbody", text: /Produkt: Hummus Classic/
    assert_select "tbody", text: /Bewertung zu Hummus Classic/
    assert_select "tbody", text: /Meldung zu Pesto Verde/
    assert_select "tbody a[href=?]", product_path(products(:hummus))
    assert_select "tbody a[href=?]", product_path(products(:pesto))
  end

  # Die Spalte «Geändert» nennt Spaltennamen. Ohne Übersetzung fällt Rails auf
  # den humanisierten englischen Namen zurück («Locked at», «Retail chain»).
  test "die geänderten Felder erscheinen auf Deutsch" do
    sign_in_as users(:moni)
    patch product_path(products(:hummus)), params: { product: {
      name: "Hummus Classic Bio", brand: "M-Classic", description: "Neu beschrieben",
      category_id: categories(:saucen).id, retail_chain_id: retail_chains(:coop).id,
      lock_version: products(:hummus).lock_version } }
    patch lock_product_path(products(:hummus))
    sign_out

    sign_in_as users(:max)
    patch block_moderation_report_path(reports(:claimed_by_max))

    get activities_path

    assert_response :success

    # Nur die Spalte «Geändert» prüfen – anderswo auf der Seite stehen
    # berechtigterweise Wörter wie «Moderator» (die Rolle in der Kopfzeile).
    changed = css_select("tbody tr td:last-child").map { |cell| cell.text.strip }.join(" | ")

    [ "Kategorie", "Handelskette", "Beschreibung", "Bezeichnung", "Sperrung", "Status", "Entschieden" ].each do |label|
      assert_includes changed, label
    end
    [ "Locked at", "Retail chain", "Category", "Decided at", "Claimed at", "Moderator" ].each do |english|
      assert_not_includes changed, english, "englische Feldnamen gehören nicht ins Protokoll"
    end
  end

  test "abgeleitete Spalten stehen nicht im Protokoll" do
    sign_in_as users(:moni)
    patch product_path(products(:hummus)), params: { product: {
      name: "Hummus Classic Bio", brand: "M-Classic",
      category_id: categories(:aufstriche).id, retail_chain_id: retail_chains(:migros).id,
      lock_version: products(:hummus).lock_version } }

    version = PaperTrail::Version.where(item_type: "Product").last
    assert_not_includes version.changeset.keys, "name_normalized",
                        "die normalisierte Fassung wiederholte nur die Bezeichnung"
  end

  test "ein gelöschtes Objekt bleibt ohne Link stehen" do
    sign_in_as users(:anna)
    delete rating_path(ratings(:anna_hummus))
    sign_out

    sign_in_as users(:moni)
    get activities_path

    assert_response :success
    assert_select "tbody span.muted", text: /Bewertung #/
  end

  test "auch Administratoren sehen das Protokoll" do
    sign_in_as users(:admin)

    get activities_path

    assert_response :success
  end

  test "der Link erscheint nur für Moderation und Administration" do
    sign_in_as users(:moni)
    get root_path
    assert_select ".site-nav a[href=?]", activities_path

    sign_out
    sign_in_as users(:anna)
    get root_path
    assert_select ".site-nav a[href=?]", activities_path, false
  end
end
