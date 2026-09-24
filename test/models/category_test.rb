require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "Name ist Pflicht" do
    category = Category.new

    assert_not category.valid?
    assert category.errors.added?(:name, :blank)
  end

  test "Name wird normalisiert gespeichert" do
    category = Category.create!(name: "  Frische   Backwaren ")

    assert_equal "Frische Backwaren", category.name
    assert_equal "frische backwaren", category.name_normalized
  end

  test "Name ist eindeutig, unabhängig von Schreibweise und Leerzeichen" do
    duplicate = Category.new(name: "  AUFSTRICHE ")

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:name_normalized, :taken)
    assert_includes duplicate.errors.full_messages, "Name gibt es bereits"
  end

  test "der Unique-Index verhindert Duplikate auch ohne Validierung" do
    assert_raises ActiveRecord::RecordNotUnique do
      Category.insert!({ name: "AUFSTRICHE", name_normalized: Category.normalize("AUFSTRICHE") })
    end
  end
end
