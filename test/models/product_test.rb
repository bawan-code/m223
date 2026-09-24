require "test_helper"

class ProductTest < ActiveSupport::TestCase
  setup do
    @attrs = { name: "Neues Produkt", brand: "Marke", category: categories(:aufstriche),
               retail_chain: retail_chains(:migros), created_by: users(:anna) }
  end

  test "Bezeichnung und Marke werden normalisiert gespeichert" do
    product = Product.create!(@attrs.merge(name: "  Hummus   PAPRIKA ", brand: " Lidl  Bio "))

    assert_equal "Hummus PAPRIKA", product.name
    assert_equal "hummus paprika", product.name_normalized
    assert_equal "lidl bio", product.brand_normalized
  end

  test "dasselbe Produkt derselben Marke bei derselben Kette ist ein Duplikat" do
    duplicate = Product.new(@attrs.merge(name: "HUMMUS classic", brand: "m-classic"))

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:name_normalized, :taken)
    assert_includes duplicate.errors.full_messages, "Bezeichnung gibt es bei dieser Kette und Marke bereits"
    assert_equal products(:hummus), duplicate.existing_duplicate
  end

  test "dasselbe Produkt bei einer anderen Kette ist erlaubt" do
    other_chain = Product.new(@attrs.merge(name: "Hummus Classic", brand: "M-Classic",
                                           retail_chain: retail_chains(:coop)))

    assert_predicate other_chain, :valid?
  end

  test "der Unique-Index verhindert Duplikate auch ohne Validierung" do
    hummus = products(:hummus)

    assert_raises ActiveRecord::RecordNotUnique do
      Product.insert!(hummus.attributes.except("id").merge("name" => "Hummus Classic"))
    end
  end

  test "Suche findet über Bezeichnung und Marke, unabhängig von Schreibweise" do
    assert_includes Product.search("HUMMUS"), products(:hummus)
    assert_includes Product.search("m-classic"), products(:pesto)
    assert_not_includes Product.search("hummus"), products(:pesto)
    assert_equal Product.count, Product.search("  ").count
  end

  test "beim Erfassen ist der Ersteller Pflicht" do
    product = Product.new(@attrs.except(:created_by))

    assert_not product.valid?
    assert product.errors.added?(:created_by, :blank)
  end

  test "ein Produkt ohne Ersteller bleibt bearbeitbar" do
    product = products(:hummus)
    product.update_column(:created_by_id, nil)

    assert product.reload.update(description: "Nach dem Löschen des Kontos bearbeitet")
  end

  test "visible blendet gesperrte Produkte aus" do
    assert_not_includes Product.visible, products(:locked_product)
    assert_includes Product.visible, products(:hummus)
  end

  test "average_rating aus den Aggregaten, nil ohne Bewertungen" do
    assert_in_delta 3.5, products(:hummus).average_rating
    assert_nil products(:locked_product).average_rating
  end

  test "stars_distribution liefert alle Sternwerte 5..1" do
    assert_equal({ 5 => 1, 4 => 0, 3 => 0, 2 => 1, 1 => 0 }, products(:hummus).stars_distribution)
  end

  test "recalculate_aggregates! zählt nur aktive Bewertungen" do
    hummus = products(:hummus)
    ratings(:ben_hummus).update!(status: :gesperrt)

    hummus.recalculate_aggregates!

    assert_equal 1, hummus.ratings_count
    assert_equal 5, hummus.ratings_sum
  end

  test "certified? ab 4 Sternen im Schnitt, gerundet wie in der Anzeige" do
    product = Product.new(ratings_count: 2, ratings_sum: 8)
    assert product.certified?

    product.ratings_sum = 7
    assert_not product.certified?, "3,5 reicht nicht"

    product.assign_attributes(ratings_count: 25, ratings_sum: 99)
    assert product.certified?, "3,96 wird als 4,0 angezeigt und trägt das Siegel"

    product.assign_attributes(ratings_count: 0, ratings_sum: 0)
    assert_not product.certified?
  end
end
