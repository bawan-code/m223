module ActivitiesHelper
  # Deutsche Namen der geänderten Felder. Bei «erfasst» und «gelöscht» wären
  # das schlicht alle Felder – das sagt nichts aus und bleibt deshalb leer.
  def changed_attribute_names(version)
    return [] unless version.event == "update"

    model = version.item_type.safe_constantize

    version.changeset.keys.excluding("updated_at").map do |attribute|
      model ? model.human_attribute_name(attribute) : attribute
    end
  end

  # Bezeichnung des betroffenen Objekts. Für gelöschte Objekte gibt es keinen
  # Datensatz mehr, dort bleibt der Typ mit der ID stehen.
  def activity_object_label(version)
    case version.item
    when Product then "#{Product.model_name.human}: #{version.item.name}"
    when Rating  then t("activities.rating_on", product: version.item.product.name)
    when Report  then t("activities.report_on", product: version.item.rating.product.name)
    else deleted_object_label(version)
    end
  end

  # Ziel des Links. Bewertungen und Meldungen haben keine eigene Seite – beide
  # sind auf der Produktseite sichtbar, dorthin führt der Eintrag. Gelöschte
  # Objekte haben kein Ziel mehr und bleiben unverlinkt.
  #
  # Bewusst nicht `link_to ..., version.item`: Rails leitet den Pfad dann aus
  # dem Modell ab und sucht ein `report_path`, das es nicht gibt.
  def activity_target_path(version)
    case version.item
    when Product then product_path(version.item)
    when Rating  then product_path(version.item.product)
    when Report  then product_path(version.item.rating.product)
    end
  end

  private

  def deleted_object_label(version)
    model = version.item_type.safe_constantize
    name = model ? model.model_name.human : version.item_type

    "#{name} ##{version.item_id}"
  end
end
