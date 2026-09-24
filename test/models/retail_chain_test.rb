require "test_helper"

class RetailChainTest < ActiveSupport::TestCase
  test "Name ist Pflicht" do
    chain = RetailChain.new

    assert_not chain.valid?
    assert chain.errors.added?(:name, :blank)
  end

  test "Name wird normalisiert gespeichert" do
    chain = RetailChain.create!(name: "  Denner  ")

    assert_equal "Denner", chain.name
    assert_equal "denner", chain.name_normalized
  end

  test "Name ist eindeutig, unabhängig von Schreibweise" do
    duplicate = RetailChain.new(name: "MIGROS")

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:name_normalized, :taken)
    assert_includes duplicate.errors.full_messages, "Name gibt es bereits"
  end

  test "der Unique-Index verhindert Duplikate auch ohne Validierung" do
    assert_raises ActiveRecord::RecordNotUnique do
      RetailChain.insert!({ name: "MIGROS", name_normalized: RetailChain.normalize("MIGROS") })
    end
  end
end
