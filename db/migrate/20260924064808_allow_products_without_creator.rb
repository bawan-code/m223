class AllowProductsWithoutCreator < ActiveRecord::Migration[8.1]
  # Der Produktkatalog gehört der Gemeinschaft: Wird ein Konto gelöscht (4.4),
  # bleiben seine Produkte bestehen und verlieren nur den Verweis auf den
  # Ersteller. Beim Erfassen ist der Ersteller weiterhin Pflicht (Validierung
  # `on: :create` in Product).
  def change
    change_column_null :products, :created_by_id, true
  end
end
