class RemoveDefaultFromReportsReason < ActiveRecord::Migration[8.1]
  # Mit dem Default 0 wurde eine Meldung ohne gewählten Grund stillschweigend
  # zu «beleidigend». Ohne Default bleibt `reason` nil, die Enum-Validierung
  # weist das Formular ab und `null: false` bleibt als Absicherung bestehen.
  def change
    change_column_default :reports, :reason, from: 0, to: nil
  end
end
