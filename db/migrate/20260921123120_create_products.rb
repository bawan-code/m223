class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :brand, null: false
      # Normalisierte Fassungen (klein, Leerzeichen bereinigt) für Suche und Duplikatprüfung
      t.string :name_normalized, null: false
      t.string :brand_normalized, null: false
      t.text :description
      t.references :category, null: false, foreign_key: true
      t.references :retail_chain, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      # Aggregate der aktiven Bewertungen; Durchschnitt = ratings_sum / ratings_count
      t.integer :ratings_count, null: false, default: 0
      t.integer :ratings_sum, null: false, default: 0
      # Gesetzt, wenn ein Moderator das Produkt gesperrt hat
      t.datetime :locked_at
      # Optimistisches Locking beim Bearbeiten durch Moderatoren
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    # Fachregel F6: dasselbe Produkt derselben Marke bei derselben Kette nur einmal –
    # der Index greift auch bei gleichzeitigen Requests.
    add_index :products, [ :name_normalized, :brand_normalized, :retail_chain_id ],
              unique: true, name: "index_products_on_normalized_identity"
    add_index :products, :name_normalized
    add_index :products, :brand_normalized
  end
end
