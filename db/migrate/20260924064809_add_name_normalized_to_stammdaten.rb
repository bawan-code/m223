class AddNameNormalizedToStammdaten < ActiveRecord::Migration[8.1]
  TABLES = %w[ categories retail_chains ].freeze

  # Der eindeutige Index auf `name` war schreibweise-abhängig: «Migros» und
  # «MIGROS» konnten nebeneinander existieren, obwohl die Modellvalidierung das
  # verbietet. Wie bei Product entscheidet jetzt eine normalisierte Spalte, die
  # der Index absichert – auch bei gleichzeitigen Anfragen.
  def up
    TABLES.each do |table|
      add_column table, :name_normalized, :string

      select_all("SELECT id, name FROM #{table}").each do |row|
        # Gleiche Normalisierung wie Normalization.normalize; Migrationen
        # bleiben bewusst unabhängig vom Modellcode.
        normalized = row["name"].to_s.unicode_normalize(:nfkc).downcase.squish
        execute "UPDATE #{table} SET name_normalized = #{quote(normalized)} WHERE id = #{row["id"]}"
      end

      change_column_null table, :name_normalized, false
      remove_index table, :name
      add_index table, :name_normalized, unique: true
    end
  end

  def down
    TABLES.each do |table|
      remove_index table, :name_normalized
      add_index table, :name, unique: true
      remove_column table, :name_normalized
    end
  end
end
