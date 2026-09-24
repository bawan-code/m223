# Aktivitätsprotokoll (PaperTrail): eine Zeile pro Änderung an Produkt,
# Bewertung und Meldung. Erzeugt vom Generator, auf das Nötige gekürzt.
class CreateVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :versions do |t|
      t.string   :item_type, null: false
      t.bigint   :item_id,   null: false
      t.string   :event,     null: false
      # Benutzer-ID als String – PaperTrail legt sich nicht auf ein Modell fest
      t.string   :whodunnit
      t.text     :object
      t.datetime :created_at
    end

    add_index :versions, %i[ item_type item_id ]
    # Für den Aktivitäten-Feed, der nach Zeitpunkt sortiert
    add_index :versions, :created_at
  end
end
