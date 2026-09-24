require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  VALID = { name: "Hummus Zitrone", brand: "Bio", description: "Frisch." }

  setup do
    @product = products(:hummus)
    @locked = products(:locked_product)
  end

  # Schnell viele Produkte anlegen, ohne 25 Validierungsläufe abzuwarten.
  def create_test_products(count)
    now = Time.current
    rows = count.times.map do |i|
      name = "Testprodukt #{i}"
      { name:, brand: "Testmarke",
        name_normalized: Product.normalize(name), brand_normalized: "testmarke",
        category_id: categories(:aufstriche).id, retail_chain_id: retail_chains(:migros).id,
        created_by_id: users(:anna).id, created_at: now, updated_at: now }
    end

    Product.insert_all(rows)
  end

  def valid_params(overrides = {})
    { product: VALID.merge(category_id: categories(:aufstriche).id,
                           retail_chain_id: retail_chains(:migros).id).merge(overrides) }
  end

  # F2: suchen und filtern

  test "die Startseite ist die Produktsuche und für Gäste offen" do
    get root_path

    assert_response :success
    assert_select "h1", "Produktsuche"
    assert_select ".product-card", Product.visible.count
  end

  test "Suche findet über Bezeichnung und Marke" do
    get products_path(q: "hummus")

    assert_select ".product-name", "Hummus Classic"
    assert_select ".product-card", 1
  end

  test "Filter nach Kategorie und Handelskette" do
    get products_path(category_id: categories(:saucen).id)
    assert_select ".product-name", "Pesto Verde"

    get products_path(retail_chain_id: retail_chains(:coop).id)
    assert_select ".product-card", 0, "das einzige Coop-Produkt ist gesperrt"
  end

  test "die Filterleiste ist aufklappbar und ohne Filter zugeklappt" do
    get products_path

    assert_select ".filter-panel" do
      assert_select "label.filter-summary", text: /Filter/
      assert_select "label.filter-summary", text: /Alle Produkte/
      # Das Formular steht immer im Markup – zugeklappt wird nur per CSS,
      # damit auf grossen Bildschirmen nichts umgeschaltet werden muss.
      assert_select ".filter-body form[action=?]", products_path
    end
    assert_select "input.filter-toggle[checked]", false, "ohne gesetzten Filter bleibt sie zugeklappt"
  end

  test "mit gesetztem Filter startet die Leiste offen und nennt die Auswahl" do
    get products_path(q: "hummus", category_id: categories(:aufstriche).id)

    assert_select "input.filter-toggle[checked]"
    assert_select "label.filter-summary", text: /hummus/
    assert_select "label.filter-summary", text: /Aufstriche/
    assert_select "select[name=category_id] option[selected][value=?]", categories(:aufstriche).id.to_s
  end

  test "ohne Treffer erscheint der Hinweis mit dem Weg zum Erfassen" do
    sign_in_as users(:anna)

    get products_path(q: "gibtesnicht")

    assert_select ".product-card", 0
    assert_select "a[href=?]", new_product_path
  end

  # Q4: Die Antwortzeit darf nicht mit dem Katalog wachsen

  test "lange Trefferlisten werden seitenweise ausgegeben" do
    create_test_products(ProductsController::PER_PAGE + 5)

    get products_path

    assert_select ".product-card", ProductsController::PER_PAGE,
                  "es werden nie mehr als PER_PAGE Karten gerendert"
    assert_select ".pagination a", text: "Weiter"
    assert_select ".pagination a", text: "Zurück", count: 0

    get products_path(page: 2)

    assert_select ".product-card", Product.visible.count - ProductsController::PER_PAGE
    assert_select ".pagination a", text: "Zurück"
  end

  test "die Seitenwahl behält Suche und Filter bei" do
    create_test_products(ProductsController::PER_PAGE + 1)

    get products_path(q: "testprodukt", retail_chain_id: retail_chains(:migros).id)

    assert_select ".pagination a[href*=?]", "q=testprodukt"
    assert_select ".pagination a[href*=?]", "retail_chain_id"
  end

  test "ohne zweite Seite erscheint keine Blätterleiste" do
    get products_path

    assert_select ".pagination", 0
  end

  # F5: Detailseite

  test "die Detailseite zeigt Durchschnitt, Anzahl, Verteilung und Kommentare" do
    get product_path(@product)

    assert_response :success
    assert_select ".rating-average", text: /3,5/
    assert_select ".rating-average", text: /2 Bewertungen/
    assert_select ".distribution"
    assert_select ".rating", text: /Cremig, gut gewürzt/
    # Die Beschreibung steht direkt unter dem Produktnamen – vor der Zeile mit
    # Marke, Handelskette und Kategorie, nicht im Bewertungsblock.
    assert_select ".list-header p.product-description:nth-child(2)",
                  text: /Kichererbsen-Aufstrich mit Sesampaste/
    assert_select ".list-header p.muted:nth-child(3)", text: /M-Classic/
    assert_select "h2", text: "Bewertung"
  end

  test "gesperrte Produkte sind für Gäste und Benutzer nicht erreichbar" do
    get product_path(@locked)
    assert_response :forbidden

    sign_in_as users(:anna)
    get product_path(@locked)
    assert_response :forbidden
  end

  test "Moderatoren sehen gesperrte Produkte" do
    sign_in_as users(:moni)

    get product_path(@locked)

    assert_response :success
    assert_select ".flash-notice", text: /gesperrt/
  end

  # F6: erfassen

  test "Gäste können keine Produkte erfassen" do
    get new_product_path
    assert_redirected_to new_session_path
  end

  test "Benutzer erfassen ein neues Produkt" do
    sign_in_as users(:anna)

    assert_difference "Product.count", 1 do
      post products_path, params: valid_params
    end

    product = Product.find_by!(name: "Hummus Zitrone")
    assert_equal users(:anna), product.created_by
    assert_redirected_to product
  end

  # Q3: Duplikat beim Erfassen

  test "ein Duplikat wird abgewiesen und auf das bestehende Produkt verwiesen" do
    sign_in_as users(:anna)

    assert_no_difference "Product.count" do
      post products_path, params: valid_params(name: "  hummus   CLASSIC ", brand: "m-classic")
    end

    assert_response :unprocessable_entity
    assert_select ".errors a[href=?]", product_path(@product), text: /Hummus Classic/
    # Die Eingabe steht unverändert im Formular, falls es sich doch um ein
    # anderes Produkt handelt – Rails zeigt den ursprünglich getippten Wert
    # (value_before_type_cast), nicht die normalisierte Fassung.
    assert_select "input[name='product[name]'][value=?]", "  hummus   CLASSIC "
  end

  test "auch der Unique-Index führt zum selben Hinweis" do
    sign_in_as users(:anna)

    raising(Product, :transaction, ActiveRecord::RecordNotUnique) do
      post products_path, params: valid_params(name: "Hummus Classic", brand: "M-Classic")
    end

    assert_response :unprocessable_entity
    assert_select ".errors a[href=?]", product_path(@product)
  end

  test "dasselbe Produkt bei einer anderen Kette ist erlaubt" do
    sign_in_as users(:anna)

    assert_difference "Product.count", 1 do
      post products_path, params: valid_params(name: "Hummus Classic", brand: "M-Classic",
                                               retail_chain_id: retail_chains(:coop).id)
    end
  end

  # F8: Moderation

  test "Benutzer dürfen Produkte weder bearbeiten noch sperren" do
    sign_in_as users(:anna)

    get edit_product_path(@product)
    assert_response :forbidden

    patch product_path(@product), params: valid_params
    assert_response :forbidden

    patch lock_product_path(@product)
    assert_response :forbidden

    assert_equal "Hummus Classic", @product.reload.name
    assert_not @product.locked?
  end

  test "Moderatoren korrigieren Produktdaten" do
    sign_in_as users(:moni)

    patch product_path(@product), params: valid_params(name: "Hummus Classic Bio",
                                                       brand: "M-Classic",
                                                       lock_version: @product.lock_version)

    assert_redirected_to @product
    assert_equal "Hummus Classic Bio", @product.reload.name
  end

  test "Moderatoren sperren und entsperren ein Produkt" do
    sign_in_as users(:moni)

    patch lock_product_path(@product)
    assert_predicate @product.reload, :locked?

    patch unlock_product_path(@product)
    assert_not_predicate @product.reload, :locked?
  end

  test "das Sperren lässt die Bewertungen und die Aggregate unangetastet" do
    sign_in_as users(:moni)

    patch lock_product_path(@product)

    @product.reload
    assert_equal 2, @product.ratings_count
    assert_equal 2, @product.ratings.count
  end

  # Q3: konkurrierende Bearbeitung (optimistisches Locking)

  test "eine veraltete Version wird abgewiesen, die erste Änderung bleibt" do
    stale_version = @product.lock_version

    moni = open_session
    moni.post session_path, params: { email_address: "moni@example.test", password: "probiert-test-2026" }
    max = open_session
    max.post session_path, params: { email_address: "max@example.test", password: "probiert-test-2026" }

    # Moni speichert zuerst
    moni.patch product_path(@product), params: valid_params(name: "Hummus von Moni", brand: "M-Classic",
                                                            lock_version: stale_version)
    assert_equal "Hummus von Moni", @product.reload.name

    # Max hatte das Formular noch mit der alten Version offen
    max.patch product_path(@product), params: valid_params(name: "Hummus von Max", brand: "M-Classic",
                                                           lock_version: stale_version)

    assert_equal 422, max.response.status
    assert_equal "Hummus von Moni", @product.reload.name, "die erste Änderung bleibt bestehen"
  end

  test "ab 4 Sternen im Schnitt tragen Detailseite und Liste das Siegel «Probiert»" do
    get product_path(@product)
    assert_select ".certificate", 0

    @product.update_columns(ratings_count: 2, ratings_sum: 9)

    get product_path(@product)
    assert_select ".rating-average .certificate"

    get products_path
    assert_select ".product-title .certificate-badge", text: "Probiert"
  end

  test "die Übersicht füllt den letzten Stern anteilig" do
    get product_path(@product)

    assert_select ".rating-average .star", 5
    assert_select ".rating-average .star-lit", 4
    assert_select ".rating-average .star-lit[style='--lit: 50%']", 1, "3,5 Sterne: der vierte ist halb gefüllt"
  end

  test "die Liste lässt sich nach bester und nach schlechtester Bewertung sortieren" do
    products(:pesto).update_columns(ratings_count: 1, ratings_sum: 5)
    Product.create!(name: "Apfelmus", brand: "M-Classic", category: categories(:aufstriche),
                    retail_chain: retail_chains(:migros), created_by: users(:anna))

    get products_path(sort: "beste")
    assert_equal [ "Pesto Verde", "Hummus Classic", "Apfelmus" ], css_select(".product-name").map { |name| name.text.strip }

    get products_path(sort: "schlechteste")
    assert_equal [ "Hummus Classic", "Pesto Verde", "Apfelmus" ], css_select(".product-name").map { |name| name.text.strip }
    assert_select "select[name=sort] option[selected][value=schlechteste]"
    assert_select "label.filter-summary", text: /Schlechteste Bewertung zuerst/
  end
end
