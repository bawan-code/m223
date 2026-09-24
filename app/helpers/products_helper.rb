module ProductsHelper
  # Illustration zur Kategorie auf der Produktkarte (app/assets/images/categories).
  # Eine Kategorie ohne eigenes Bild – etwa eine spätere aus F12 – bekommt den
  # Planeten.
  CATEGORY_ILLUSTRATIONS = {
    "Aufstriche" => "glas",
    "Saucen" => "rakete",
    "Milchprodukte" => "milch",
    "Snacks" => "marshmallow",
    "Getränke" => "getraenk",
    "Fertiggerichte" => "ufo"
  }.transform_keys { |name| Category.normalize(name) }.freeze

  def category_illustration(category)
    file = CATEGORY_ILLUSTRATIONS.fetch(category.name_normalized, "planet")

    image_tag "categories/#{file}.svg", alt: category.name, title: category.name,
              class: "product-illustration", size: 56
  end

  # Kurzfassung der gesetzten Filter für die zugeklappte Filterleiste – damit
  # auch im eingeklappten Zustand erkennbar bleibt, wonach gefiltert wird.
  # Arbeitet auf den bereits geladenen Sammlungen, ohne zusätzliche Abfrage.
  def active_filters(categories, retail_chains)
    [
      params[:q].presence,
      categories.find { |category| category.id.to_s == params[:category_id] }&.name,
      retail_chains.find { |chain| chain.id.to_s == params[:retail_chain_id] }&.name
    ].compact
  end
end
