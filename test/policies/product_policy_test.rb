require "test_helper"

class ProductPolicyTest < ActiveSupport::TestCase
  setup do
    @product = products(:hummus)
    @locked = products(:locked_product)
  end

  # Gast: darf lesen, aber nichts verändern

  test "Gäste sehen sichtbare Produkte, aber keine gesperrten" do
    assert ProductPolicy.new(nil, @product).show?
    assert_not ProductPolicy.new(nil, @locked).show?
  end

  test "Gäste dürfen keine Produkte erfassen oder bearbeiten" do
    assert_not ProductPolicy.new(nil, Product.new).create?
    assert_not ProductPolicy.new(nil, @product).update?
    assert_not ProductPolicy.new(nil, @product).lock?
  end

  # Benutzer: erfassen ja, korrigieren nein

  test "Benutzer dürfen Produkte erfassen" do
    assert ProductPolicy.new(users(:anna), Product.new).create?
  end

  test "Benutzer dürfen fremde Produkte nicht bearbeiten oder sperren" do
    assert_not ProductPolicy.new(users(:anna), @product).update?
    assert_not ProductPolicy.new(users(:anna), @product).lock?
    assert_not ProductPolicy.new(users(:ben), products(:pesto)).update?,
               "auch nicht das selbst erfasste Produkt – dafür ist die Moderation da"
  end

  test "auch Benutzer sehen gesperrte Produkte nicht" do
    assert_not ProductPolicy.new(users(:anna), @locked).show?
  end

  # Moderator

  test "Moderatoren korrigieren und sperren jedes Produkt" do
    policy = ProductPolicy.new(users(:moni), @product)

    assert policy.update?
    assert policy.lock?
    assert policy.unlock?
    assert ProductPolicy.new(users(:moni), @locked).show?
  end

  # Administrator erbt die Rechte der Moderation

  test "Administratoren dürfen dasselbe wie Moderatoren" do
    assert ProductPolicy.new(users(:admin), @product).update?
    assert ProductPolicy.new(users(:admin), @locked).show?
  end

  # Produkte werden gesperrt, nicht gelöscht

  test "niemand darf Produkte löschen" do
    [ nil, users(:anna), users(:moni), users(:admin) ].each do |actor|
      assert_not ProductPolicy.new(actor, @product).destroy?
    end
  end

  # Scope

  test "gesperrte Produkte fehlen im Scope aller ausser der Moderation" do
    assert_not_includes ProductPolicy::Scope.new(nil, Product).resolve, @locked
    assert_not_includes ProductPolicy::Scope.new(users(:anna), Product).resolve, @locked
    assert_includes ProductPolicy::Scope.new(users(:moni), Product).resolve, @locked
    assert_includes ProductPolicy::Scope.new(users(:admin), Product).resolve, @locked
  end

  test "lock_version gehört zu den erlaubten Feldern" do
    assert_includes ProductPolicy.new(users(:moni), @product).permitted_attributes, :lock_version
  end
end
