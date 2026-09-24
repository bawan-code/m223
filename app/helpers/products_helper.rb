module ProductsHelper
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
