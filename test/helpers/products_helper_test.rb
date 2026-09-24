require "test_helper"

class ProductsHelperTest < ActionView::TestCase
  test "category_illustration zeigt das Bild der Kategorie mit ihrem Namen als Alternativtext" do
    html = category_illustration(categories(:saucen))

    assert_includes html, "categories/rakete"
    assert_includes html, 'alt="Saucen"'
  end

  test "eine Kategorie ohne eigenes Bild bekommt den Planeten" do
    html = category_illustration(Category.new(name: "Tiefkühl", name_normalized: "tiefkühl"))

    assert_includes html, "categories/planet"
  end
end
