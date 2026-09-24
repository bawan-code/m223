require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  VALID = { name: "Hummus Zitrone", brand: "Bio", description: "Frisch." }

  setup do
    @product = products(:hummus)
    @locked = products(:locked_product)
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
  end

  test "ohne Treffer erscheint der Hinweis mit dem Weg zum Erfassen" do
    sign_in_as users(:anna)

    get products_path(q: "gibtesnicht")

    assert_select ".product-card", 0
    assert_select "a[href=?]", new_product_path
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
end
