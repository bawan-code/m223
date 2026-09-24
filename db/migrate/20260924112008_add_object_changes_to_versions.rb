# Speichert je Version die geänderten Felder mit Vorher/Nachher-Wert.
# Grundlage für die Spalte «Geändert» im Aktivitäten-Feed (version.changeset).
class AddObjectChangesToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :versions, :object_changes, :text
  end
end
