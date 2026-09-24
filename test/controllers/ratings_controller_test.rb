require "test_helper"

class RatingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:hummus)
    @moni = users(:moni)   # hat hummus noch nicht bewertet
  end

  # F3: Kernfunktion

  test "Gast wird beim Bewerten zur Anmeldung geleitet" do
    assert_no_difference "Rating.count" do
      post product_ratings_path(@product), params: { rating: { stars: 4 } }
    end

    assert_redirected_to new_session_path
  end

  test "Bewertung abgeben führt die Aggregate des Produkts nach" do
    sign_in_as @moni

    assert_difference "Rating.count", 1 do
      post product_ratings_path(@product), params: { rating: { stars: 4, comment: "Solide." } }
    end

    assert_redirected_to @product
    follow_redirect!
    assert_select ".flash-notice", text: /gespeichert/

    @product.reload
    assert_equal 3, @product.ratings_count
    assert_equal 11, @product.ratings_sum
    assert_in_delta 3.67, @product.average_rating, 0.01
  end

  test "ohne Sterne bleibt die Produktseite mit Fehlermeldung stehen" do
    sign_in_as @moni

    assert_no_difference "Rating.count" do
      post product_ratings_path(@product), params: { rating: { stars: "", comment: "Nur Text" } }
    end

    assert_response :unprocessable_entity
    assert_select ".errors li", text: /Sterne/
  end

  # Q3: Doppelbewertung

  test "die zweite Bewertung führt zur bestehenden statt eine neue anzulegen" do
    sign_in_as users(:anna)   # hat hummus bereits mit 5 bewertet

    assert_no_difference "Rating.count" do
      post product_ratings_path(@product), params: { rating: { stars: 2, comment: "Doch nicht so gut" } }
    end

    existing = ratings(:anna_hummus)
    assert_redirected_to edit_rating_path(existing, rating: { stars: "2", comment: "Doch nicht so gut" })

    follow_redirect!
    assert_select ".flash-notice", text: /bereits bewertet/
    # Die soeben eingegebenen Werte stehen im Formular, nicht die gespeicherten
    assert_select "input[name='rating[stars]'][value='2'][checked]"
    assert_select "textarea[name='rating[comment]']", text: /Doch nicht so gut/
    assert_equal 5, existing.reload.stars, "gespeichert ist weiterhin die alte Bewertung"
  end

  test "ein gleichzeitiger zweiter Request wird vom Unique-Index abgefangen" do
    sign_in_as users(:anna)

    # Simuliert den Gleichzeitigkeitsfall: die Validierung war noch zufrieden,
    # der Unique-Index schlägt beim Schreiben zu.
    raising(Rating, :submit!, ActiveRecord::RecordNotUnique) do
      assert_no_difference "Rating.count" do
        post product_ratings_path(@product), params: { rating: { stars: 3 } }
      end
    end

    assert_response :redirect
    assert_match %r{/ratings/#{ratings(:anna_hummus).id}/edit}, response.location
    assert_match(/stars%5D=3/, response.location, "die Eingabe wird mitgegeben")
    follow_redirect!
    assert_select ".flash-notice", text: /bereits bewertet/
  end

  # gesperrtes Produkt

  test "ein gesperrtes Produkt nimmt keine Bewertung an" do
    sign_in_as @moni

    assert_no_difference "Rating.count" do
      post product_ratings_path(products(:locked_product)), params: { rating: { stars: 5 } }
    end

    assert_redirected_to products(:locked_product)
    follow_redirect!
    assert_select ".flash-alert", text: /gesperrt/
  end

  # F4: ändern und löschen

  test "die eigene Bewertung ändern korrigiert die Aggregate" do
    sign_in_as users(:anna)

    patch rating_path(ratings(:anna_hummus)), params: { rating: { stars: 1 } }

    assert_redirected_to @product
    assert_equal 1, ratings(:anna_hummus).reload.stars
    @product.reload
    assert_equal 2, @product.ratings_count
    assert_equal 3, @product.ratings_sum
  end

  test "die Produktseite kann nicht direkt löschen, sie verlinkt nur die Bestätigung" do
    sign_in_as users(:anna)

    get product_path(@product)

    assert_select "a[href=?]", confirm_destroy_rating_path(ratings(:anna_hummus))
    assert_select "form[action=?]", rating_path(ratings(:anna_hummus)), false,
                  "von der Produktseite aus darf kein Löschformular abgeschickt werden können"
  end

  test "die Bestätigungsseite zeigt die Bewertung und die Folgen" do
    sign_in_as users(:anna)

    get confirm_destroy_rating_path(ratings(:anna_hummus))

    assert_response :success
    assert_select "h1", "Deine Bewertung löschen?"
    assert_select ".rating", text: /Cremig, gut gewürzt/
    assert_select "form[action=?]", rating_path(ratings(:anna_hummus))
  end

  test "die Bestätigungsseite einer fremden Bewertung ist gesperrt" do
    sign_in_as users(:ben)

    get confirm_destroy_rating_path(ratings(:anna_hummus))

    assert_response :forbidden
  end

  test "die eigene Bewertung löschen korrigiert die Aggregate" do
    sign_in_as users(:anna)

    assert_difference "Rating.count", -1 do
      delete rating_path(ratings(:anna_hummus))
    end

    @product.reload
    assert_equal 1, @product.ratings_count
    assert_equal 2, @product.ratings_sum
  end

  test "eine fremde Bewertung lässt sich weder ändern noch löschen" do
    sign_in_as users(:ben)

    patch rating_path(ratings(:anna_hummus)), params: { rating: { stars: 1 } }
    assert_response :forbidden

    delete rating_path(ratings(:anna_hummus))
    assert_response :forbidden

    assert_equal 5, ratings(:anna_hummus).reload.stars
  end

  test "auch Moderatoren ändern fremde Bewertungen nicht" do
    sign_in_as @moni

    patch rating_path(ratings(:anna_hummus)), params: { rating: { stars: 1 } }

    assert_response :forbidden
    assert_equal 5, ratings(:anna_hummus).reload.stars
  end

  test "eine mitgeschickte fremde user_id wird ignoriert" do
    sign_in_as @moni

    post product_ratings_path(@product), params: { rating: { stars: 4, user_id: users(:ben).id } }

    assert_equal @moni, Rating.order(:created_at).last.user
  end
end
