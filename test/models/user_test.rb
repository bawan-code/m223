require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "E-Mail wird klein geschrieben und getrimmt" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")

    assert_equal "downcased@example.com", user.email_address
  end

  test "Name, E-Mail und Passwort sind Pflicht" do
    user = User.new

    assert_not user.valid?
    assert user.errors.added?(:name, :blank)
    assert user.errors.added?(:email_address, :blank)
    assert user.errors.added?(:password, :blank)
  end

  test "E-Mail muss eindeutig sein, unabhängig von Gross-/Kleinschreibung" do
    user = User.new(name: "Doppelt", email_address: "ANNA@example.test", password: "probiert-test-2026")

    assert_not user.valid?
    assert user.errors.added?(:email_address, :taken, value: "anna@example.test")
  end

  test "Passwort muss mindestens 12 Zeichen haben" do
    user = User.new(name: "Kurz", email_address: "kurz@example.test", password: "elfzeichen1")

    assert_not user.valid?
    assert user.errors.added?(:password, :too_short, count: 12)
  end

  test "ein leeres Feld für die neue E-Mail bedeutet keine vorgemerkte Adresse" do
    user = users(:anna)

    assert user.update(unconfirmed_email: "   ")
    assert_nil user.unconfirmed_email
  end

  test "eine vorgemerkte E-Mail muss gültig sein" do
    user = users(:anna)

    assert_not user.update(unconfirmed_email: "keine-adresse")
    assert user.errors.added?(:unconfirmed_email, :invalid, value: "keine-adresse")
  end

  test "Löschen des Kontos entfernt die Bewertungen, lässt die Produkte aber im Katalog" do
    anna = users(:anna)
    product = products(:hummus)

    assert_difference "Rating.count", -anna.ratings.count do
      assert_no_difference "Product.count" do
        assert anna.destroy, anna.errors.full_messages.to_sentence
      end
    end

    assert_nil product.reload.created_by_id
  end

  test "neue Benutzer haben die Rolle benutzer" do
    assert_predicate User.new, :benutzer?
  end

  test "moderator_or_admin? gilt für Moderator und Administrator" do
    assert_predicate users(:moni), :moderator_or_admin?
    assert_predicate users(:admin), :moderator_or_admin?
    assert_not users(:anna).moderator_or_admin?
  end

  test "locked? spiegelt locked_at" do
    assert_predicate users(:locked), :locked?
    assert_not users(:anna).locked?
  end
end
