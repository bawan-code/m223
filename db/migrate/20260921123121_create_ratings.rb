class CreateRatings < ActiveRecord::Migration[8.1]
  def change
    create_table :ratings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :stars, null: false
      t.text :comment
      # enum: aktiv (0), gesperrt (1)
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    # Fachregel F3: höchstens eine Bewertung pro Benutzer und Produkt –
    # auch wenn derselbe Benutzer in zwei Sitzungen gleichzeitig abschickt.
    add_index :ratings, [ :user_id, :product_id ], unique: true
  end
end
