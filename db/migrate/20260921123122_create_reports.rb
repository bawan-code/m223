class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :rating, null: false, foreign_key: true
      t.references :reporter, null: false, foreign_key: { to_table: :users }
      # Wird beim Übernehmen unter Sperre gesetzt; danach für andere Moderatoren gesperrt
      t.references :moderator, null: true, foreign_key: { to_table: :users }
      # enum: beleidigend (0), spam (1), kein_bezug (2), anderes (3)
      t.integer :reason, null: false, default: 0
      # enum: offen (0), in_bearbeitung (1), freigegeben (2), gesperrt (3)
      t.integer :status, null: false, default: 0
      t.datetime :claimed_at
      t.datetime :decided_at

      t.timestamps
    end

    # Ein Benutzer kann dieselbe Bewertung nur einmal melden
    add_index :reports, [ :rating_id, :reporter_id ], unique: true
  end
end
