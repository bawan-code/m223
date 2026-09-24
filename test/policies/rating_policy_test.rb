require "test_helper"

class RatingPolicyTest < ActiveSupport::TestCase
  setup do
    @own = ratings(:anna_hummus)      # gehört anna
    @foreign = ratings(:ben_hummus)   # gehört ben
  end

  # Gast

  test "Gäste dürfen nicht bewerten" do
    assert_not RatingPolicy.new(nil, Rating.new(product: products(:hummus))).create?
    assert_not RatingPolicy.new(nil, @own).update?
    assert_not RatingPolicy.new(nil, @own).destroy?
  end

  # Benutzer

  test "angemeldete Benutzer dürfen ein offenes Produkt bewerten" do
    assert RatingPolicy.new(users(:moni), Rating.new(product: products(:hummus))).create?
  end

  test "ein gesperrtes Produkt lässt sich nicht bewerten" do
    assert_not RatingPolicy.new(users(:anna), Rating.new(product: products(:locked_product))).create?
  end

  test "nur der Verfasser ändert und löscht seine Bewertung" do
    assert RatingPolicy.new(users(:anna), @own).update?
    assert RatingPolicy.new(users(:anna), @own).destroy?
    assert RatingPolicy.new(users(:anna), @own).confirm_destroy?

    assert_not RatingPolicy.new(users(:ben), @own).update?
    assert_not RatingPolicy.new(users(:ben), @own).destroy?
    assert_not RatingPolicy.new(users(:ben), @own).confirm_destroy?
  end

  # Moderator

  test "Moderatoren sperren fremde Bewertungen, schreiben sie aber nicht um" do
    policy = RatingPolicy.new(users(:moni), @foreign)

    assert policy.block?
    assert policy.unblock?
    assert_not policy.update?, "sonst stünde eine fremde Meinung unter seinem Namen"
    assert_not policy.destroy?
  end

  test "Benutzer dürfen keine Bewertungen sperren" do
    assert_not RatingPolicy.new(users(:anna), @foreign).block?
    assert_not RatingPolicy.new(nil, @foreign).block?
  end

  # Administrator

  test "Administratoren dürfen sperren wie Moderatoren" do
    assert RatingPolicy.new(users(:admin), @foreign).block?
  end

  # Sichtbarkeit gesperrter Bewertungen

  test "gesperrte Bewertungen sehen nur Verfasser und Moderation" do
    @foreign.update!(status: :gesperrt)

    assert_not RatingPolicy.new(nil, @foreign).show?
    assert_not RatingPolicy.new(users(:anna), @foreign).show?
    assert RatingPolicy.new(users(:ben), @foreign).show?, "der Verfasser sieht seine eigene"
    assert RatingPolicy.new(users(:moni), @foreign).show?
  end

  test "der Scope blendet gesperrte Bewertungen aus" do
    @foreign.update!(status: :gesperrt)

    assert_not_includes RatingPolicy::Scope.new(users(:anna), Rating).resolve, @foreign
    assert_includes RatingPolicy::Scope.new(users(:moni), Rating).resolve, @foreign
  end
end
