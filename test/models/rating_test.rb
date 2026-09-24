require "test_helper"

class RatingTest < ActiveSupport::TestCase
  test "Sterne müssen zwischen 1 und 5 liegen" do
    rating = Rating.new(user: users(:moni), product: products(:hummus))

    [ 0, 6, nil ].each do |stars|
      rating.stars = stars
      assert_not rating.valid?, "#{stars.inspect} sollte ungültig sein"
      assert rating.errors.added?(:stars, :inclusion, value: stars)
    end

    rating.stars = 3
    assert_predicate rating, :valid?
  end

  test "Kommentar ist optional und wird getrimmt" do
    rating = Rating.new(comment: "   ")

    assert_nil rating.comment
  end

  test "pro Benutzer und Produkt höchstens eine Bewertung" do
    second = Rating.new(user: users(:anna), product: products(:hummus), stars: 3)

    assert_not second.valid?
    assert second.errors.of_kind?(:user_id, :taken)
    assert_includes second.errors.full_messages, "Bewertung für dieses Produkt gibt es von dir bereits"
  end

  test "der Unique-Index verhindert eine zweite Bewertung auch ohne Validierung" do
    assert_raises ActiveRecord::RecordNotUnique do
      Rating.insert!({ user_id: users(:anna).id, product_id: products(:hummus).id, stars: 3 })
    end
  end

  test "gesperrte Produkte können nicht bewertet werden" do
    rating = Rating.new(user: users(:anna), product: products(:locked_product), stars: 4)

    assert_not rating.valid?
    assert rating.errors.added?(:product, :locked)
  end

  test "bestehende Bewertung eines gesperrten Produkts bleibt änderbar" do
    ratings(:anna_hummus).product.update!(locked_at: Time.current)

    assert ratings(:anna_hummus).update(stars: 4)
  end

  # Q1: Anzahl und Durchschnitt entsprechen immer den gespeicherten Bewertungen

  test "submit! speichert die Bewertung und führt die Aggregate nach" do
    product = products(:pesto)
    rating = product.ratings.new(user: users(:moni), stars: 5)

    Rating.submit!(rating)

    product.reload
    assert_predicate rating, :persisted?
    assert_equal 2, product.ratings_count
    assert_equal 6, product.ratings_sum
    assert_in_delta 3.0, product.average_rating
  end

  test "submit! weist ein gesperrtes Produkt ab, ohne etwas zu speichern" do
    product = products(:locked_product)
    rating = product.ratings.new(user: users(:moni), stars: 5)

    assert_raises Rating::ProductLocked do
      Rating.submit!(rating)
    end

    assert_not rating.persisted?
    assert_equal 0, product.reload.ratings_count
  end

  test "ändern, zurückziehen und sperren halten die Aggregate korrekt" do
    product = products(:hummus)
    rating = ratings(:anna_hummus)   # 5 Sterne, dazu ben mit 2

    rating.change!(stars: 3)
    product.reload
    assert_equal 2, product.ratings_count
    assert_equal 5, product.ratings_sum

    rating.block!
    product.reload
    assert_equal 1, product.ratings_count
    assert_equal 2, product.ratings_sum

    rating.unblock!
    product.reload
    assert_equal 2, product.ratings_count

    rating.withdraw!
    product.reload
    assert_equal 1, product.ratings_count
    assert_equal 2, product.ratings_sum
  end

  test "auch nach 50 Bewertungen stimmen Anzahl und Summe" do
    product = products(:locked_product)
    product.update!(locked_at: nil)
    expected_sum = 0

    50.times do |i|
      stars = (i % 5) + 1
      expected_sum += stars
      user = User.create!(name: "Testperson #{i}", email_address: "test#{i}@example.test",
                          password: "probiert-test-2026")
      Rating.submit!(product.ratings.new(user:, stars:))
    end

    product.reload
    assert_equal 50, product.ratings_count
    assert_equal expected_sum, product.ratings_sum
    assert_equal product.ratings.active.count, product.ratings_count
    assert_equal product.ratings.active.sum(:stars), product.ratings_sum
  end

  test "active enthält nur aktive Bewertungen" do
    ratings(:ben_hummus).update!(status: :gesperrt)

    assert_not_includes Rating.active, ratings(:ben_hummus)
    assert_includes Rating.active, ratings(:anna_hummus)
  end
end
