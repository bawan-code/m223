require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = "probiert-test-2026"

  # Zugriff

  test "Gast wird zur Anmeldung geleitet" do
    get admin_users_path

    assert_redirected_to new_session_path
  end

  test "Benutzer erhält auf allen Admin-Actions 403" do
    sign_in_as users(:anna)
    ben = users(:ben)

    get admin_users_path
    assert_response :forbidden

    get edit_admin_user_path(ben)
    assert_response :forbidden

    patch admin_user_path(ben), params: { user: { name: "Gekapert" } }
    assert_response :forbidden

    patch lock_admin_user_path(ben)
    assert_response :forbidden

    delete admin_user_path(ben)
    assert_response :forbidden

    assert_equal "Ben Meier", ben.reload.name
    assert_not ben.locked?
  end

  test "Moderator erhält 403 – die Benutzerverwaltung gehört der Administration" do
    sign_in_as users(:moni)

    get admin_users_path
    assert_response :forbidden

    patch admin_user_path(users(:anna)), params: { user: { role: "administrator" } }
    assert_response :forbidden
    assert_predicate users(:anna).reload, :benutzer?
  end

  test "die 403-Seite erklärt den Grund statt umzuleiten" do
    sign_in_as users(:anna)

    get admin_users_path

    assert_response :forbidden
    assert_select "h1", "Kein Zugriff"
  end

  # Übersicht

  test "Administrator sieht alle Konten mit Name, E-Mail und Rolle" do
    sign_in_as users(:admin)

    get admin_users_path

    assert_response :success
    assert_select "tbody tr", User.count
    assert_select "tbody", text: /Anna Keller/
    assert_select "tbody", text: /anna@example\.test/
    assert_select "tbody", text: /Moderator/
  end

  test "der Link zur Benutzerverwaltung erscheint nur für Administratoren" do
    sign_in_as users(:admin)
    get root_path
    assert_select ".site-nav a[href=?]", admin_users_path

    sign_out
    sign_in_as users(:moni)
    get root_path
    assert_select ".site-nav a[href=?]", admin_users_path, false
  end

  # Benutzerdetails bearbeiten

  test "Administrator ändert Name und E-Mail eines Benutzers" do
    sign_in_as users(:admin)

    patch admin_user_path(users(:anna)),
          params: { user: { name: "Anna Keller-Meier", email_address: "ANNA.NEU@example.test" } }

    assert_redirected_to admin_users_path
    anna = users(:anna).reload
    assert_equal "Anna Keller-Meier", anna.name
    assert_equal "anna.neu@example.test", anna.email_address
  end

  test "eine offene E-Mail-Bestätigung des Benutzers wird dabei verworfen" do
    users(:anna).update!(unconfirmed_email: "wunsch@example.test")
    sign_in_as users(:admin)

    patch admin_user_path(users(:anna)), params: { user: { email_address: "gesetzt@example.test" } }

    anna = users(:anna).reload
    assert_equal "gesetzt@example.test", anna.email_address
    assert_nil anna.unconfirmed_email
  end

  test "eine bereits vergebene E-Mail wird abgelehnt, Eingaben bleiben stehen" do
    sign_in_as users(:admin)

    patch admin_user_path(users(:anna)),
          params: { user: { name: "Anna Neu", email_address: "ben@example.test" } }

    assert_response :unprocessable_entity
    assert_select ".errors li", text: /E-Mail ist bereits vergeben/
    assert_select "input[name='user[name]'][value=?]", "Anna Neu"
    assert_equal "anna@example.test", users(:anna).reload.email_address
  end

  # Rollen

  test "Administrator ändert die Rolle eines Benutzers" do
    sign_in_as users(:admin)

    patch admin_user_path(users(:anna)), params: { user: { role: "moderator" } }

    assert_predicate users(:anna).reload, :moderator?
  end

  test "Administrator kann sich nicht selbst herabstufen" do
    admin = users(:admin)
    sign_in_as admin

    patch admin_user_path(admin), params: { user: { name: "Admin", role: "benutzer" } }

    assert_predicate admin.reload, :administrator?
    assert_equal "Admin", admin.name, "Name und E-Mail bleiben trotzdem änderbar"
  end

  test "das Formular blendet die Rollenauswahl beim eigenen Konto aus" do
    sign_in_as users(:admin)

    get edit_admin_user_path(users(:anna))
    assert_select "select[name='user[role]']"

    get edit_admin_user_path(users(:admin))
    assert_select "select[name='user[role]']", false
  end

  # Sperren

  test "Sperren beendet die Sitzungen und verhindert die Anmeldung" do
    anna = users(:anna)
    anna.sessions.create!
    sign_in_as users(:admin)

    patch lock_admin_user_path(anna)

    assert_redirected_to admin_users_path
    assert_predicate anna.reload, :locked?
    assert_empty anna.sessions

    sign_out
    post session_path, params: { email_address: anna.email_address, password: PASSWORD }
    assert_match(/gesperrt/, flash[:alert])
  end

  test "Entsperren erlaubt die Anmeldung wieder" do
    locked = users(:locked)
    sign_in_as users(:admin)

    patch unlock_admin_user_path(locked)

    assert_not_predicate locked.reload, :locked?
  end

  test "Administrator kann sich nicht selbst sperren" do
    admin = users(:admin)
    sign_in_as admin

    patch lock_admin_user_path(admin)

    assert_response :forbidden
    assert_not_predicate admin.reload, :locked?
  end

  # Löschen

  test "die Übersicht kann nicht direkt löschen, sie verlinkt nur die Bestätigung" do
    sign_in_as users(:admin)

    get admin_users_path

    assert_select "a[href=?]", confirm_destroy_admin_user_path(users(:anna))
    assert_select "form[action=?]", admin_user_path(users(:anna)), false,
                  "aus der Übersicht darf kein Löschformular abgeschickt werden können"
  end

  test "die Bestätigungsseite nennt die Folgen des Löschens" do
    sign_in_as users(:admin)

    get confirm_destroy_admin_user_path(users(:ben))

    assert_response :success
    assert_select "h1", "Konto von Ben Meier löschen?"
    assert_select "li", text: /1 Bewertung wird gelöscht/
    assert_select "li", text: /2 erfasste Produkte bleiben im Katalog/
    assert_select "form[action=?]", admin_user_path(users(:ben))
  end

  test "die Bestätigungsseite ist für das eigene Konto und für Nicht-Admins gesperrt" do
    sign_in_as users(:admin)
    get confirm_destroy_admin_user_path(users(:admin))
    assert_response :forbidden

    sign_out
    sign_in_as users(:moni)
    get confirm_destroy_admin_user_path(users(:anna))
    assert_response :forbidden
  end

  test "Konto löschen entfernt die Bewertungen und führt die Aggregate nach" do
    ben = users(:ben)
    hummus = products(:hummus)
    sign_in_as users(:admin)

    assert_difference "Rating.count", -ben.ratings.count do
      delete admin_user_path(ben)
    end

    assert_redirected_to admin_users_path
    assert_not User.exists?(ben.id)

    hummus.reload
    assert_equal 1, hummus.ratings_count
    assert_equal 5, hummus.ratings_sum
    assert_equal hummus.ratings.active.count, hummus.ratings_count
  end

  test "die erfassten Produkte bleiben nach dem Löschen im Katalog" do
    ben = users(:ben)
    pesto = products(:pesto)
    sign_in_as users(:admin)

    delete admin_user_path(ben)

    assert Product.exists?(pesto.id)
    assert_nil pesto.reload.created_by_id
  end

  test "Administrator kann sein eigenes Konto nicht löschen" do
    admin = users(:admin)
    sign_in_as admin

    delete admin_user_path(admin)

    assert_response :forbidden
    assert User.exists?(admin.id)
  end

  # Unbekannte IDs

  test "eine unbekannte Benutzer-ID ergibt eine verständliche 404-Seite" do
    sign_in_as users(:admin)

    get edit_admin_user_path(id: 999_999)

    assert_response :not_found
    assert_select "h1", "Nicht gefunden"
  end
end
