require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @other = users(:anna)
  end

  # Gast

  test "Gäste sehen die Benutzerverwaltung nicht" do
    policy = UserPolicy.new(nil, User)

    assert_not policy.index?
    assert_not UserPolicy.new(nil, @other).update?
  end

  # Benutzer

  test "Benutzer dürfen die Benutzerverwaltung nicht öffnen" do
    assert_not UserPolicy.new(users(:anna), User).index?
    assert_not UserPolicy.new(users(:anna), users(:ben)).update?
    assert_not UserPolicy.new(users(:anna), users(:ben)).destroy?
  end

  # Moderator – Benutzerverwaltung bleibt der Administration vorbehalten

  test "Moderatoren dürfen die Benutzerverwaltung nicht öffnen" do
    assert_not UserPolicy.new(users(:moni), User).index?
    assert_not UserPolicy.new(users(:moni), users(:anna)).update?
    assert_not UserPolicy.new(users(:moni), users(:anna)).lock?
  end

  # Administrator

  test "Administratoren verwalten fremde Konten" do
    policy = UserPolicy.new(@admin, @other)

    assert UserPolicy.new(@admin, User).index?
    assert policy.update?
    assert policy.edit?
    assert policy.lock?
    assert policy.unlock?
    assert policy.destroy?
    assert policy.confirm_destroy?
  end

  test "Administratoren können ihr eigenes Konto nicht sperren oder löschen" do
    policy = UserPolicy.new(@admin, @admin)

    assert_not policy.lock?
    assert_not policy.destroy?
    assert_not policy.confirm_destroy?, "auch die Bestätigungsseite bleibt zu"
    assert policy.update?, "Name und E-Mail des eigenen Kontos bleiben änderbar"
  end

  # permitted_attributes

  test "die Rolle ist nur bei fremden Konten erlaubt" do
    assert_includes UserPolicy.new(@admin, @other).permitted_attributes, :role
    assert_not_includes UserPolicy.new(@admin, @admin).permitted_attributes, :role
  end

  test "Name und E-Mail sind immer erlaubt" do
    [ @other, @admin ].each do |record|
      attributes = UserPolicy.new(@admin, record).permitted_attributes

      assert_includes attributes, :name
      assert_includes attributes, :email_address
    end
  end

  # Scope

  test "nur Administratoren sehen überhaupt Benutzer" do
    assert_equal User.count, UserPolicy::Scope.new(@admin, User).resolve.count
    assert_empty UserPolicy::Scope.new(users(:moni), User).resolve
    assert_empty UserPolicy::Scope.new(nil, User).resolve
  end
end
