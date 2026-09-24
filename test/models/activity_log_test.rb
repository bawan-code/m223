require "test_helper"

# Das Aktivitätsprotokoll entsteht innerhalb der Transaktionen der Kernfunktion:
# Änderung, Aggregate und Protokolleintrag sind eine Einheit.
class ActivityLogTest < ActionDispatch::IntegrationTest
  test "eine erfolgreiche Bewertung erzeugt genau einen Eintrag mit dem Verfasser" do
    moni = users(:moni)
    sign_in_as moni

    assert_difference "PaperTrail::Version.count", 1 do
      post product_ratings_path(products(:hummus)), params: { rating: { stars: 4 } }
    end

    version = PaperTrail::Version.last
    assert_equal "Rating", version.item_type
    assert_equal "create", version.event
    assert_equal moni.id.to_s, version.whodunnit
  end

  test "eine abgewiesene Bewertung hinterlässt keinen Eintrag" do
    sign_in_as users(:moni)

    assert_no_difference "PaperTrail::Version.count" do
      post product_ratings_path(products(:locked_product)), params: { rating: { stars: 5 } }
    end
  end

  test "auch eine fehlgeschlagene Validierung hinterlässt keinen Eintrag" do
    sign_in_as users(:moni)

    assert_no_difference "PaperTrail::Version.count" do
      post product_ratings_path(products(:hummus)), params: { rating: { stars: "" } }
    end
  end

  test "das Nachführen der Aggregate erzeugt keinen Eintrag am Produkt" do
    sign_in_as users(:moni)

    post product_ratings_path(products(:hummus)), params: { rating: { stars: 4 } }

    assert_empty PaperTrail::Version.where(item_type: "Product"),
                 "abgeleitete Werte gehören nicht ins Protokoll"
  end

  test "Sperren und Entscheiden einer Meldung werden protokolliert" do
    sign_in_as users(:max)

    patch block_moderation_report_path(reports(:claimed_by_max))

    events = PaperTrail::Version.where(whodunnit: users(:max).id.to_s)
    assert_includes events.pluck(:item_type), "Rating"
    assert_includes events.pluck(:item_type), "Report"
  end

  test "der Produktverlauf steht nur der Moderation offen" do
    sign_in_as users(:moni)
    patch product_path(products(:hummus)),
          params: { product: { name: "Hummus Classic Bio", brand: "M-Classic",
                               category_id: categories(:aufstriche).id,
                               retail_chain_id: retail_chains(:migros).id,
                               lock_version: products(:hummus).lock_version } }

    get product_path(products(:hummus))
    assert_select "h2", text: "Verlauf"

    sign_out
    get product_path(products(:hummus))
    assert_select "h2", text: "Verlauf", count: 0
  end
end
