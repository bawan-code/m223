# Einheitliche Normalisierung von Freitext für Duplikatprüfung und Suche:
# Unicode-Schreibweise vereinheitlichen, klein schreiben, Leerzeichen
# bereinigen. Das Ergebnis wird in eigenen `*_normalized`-Spalten gespeichert,
# damit ein eindeutiger Index die Fachregel auch bei gleichzeitigen Anfragen
# durchsetzt – SQLite kennt keinen Unicode-fähigen Vergleich ohne
# Gross-/Kleinschreibung.
module Normalization
  extend ActiveSupport::Concern

  class_methods do
    def normalize(value)
      value.to_s.unicode_normalize(:nfkc).downcase.squish
    end
  end
end
