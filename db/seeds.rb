# Demo-Daten für die Entwicklung. Tests verwenden Fixtures (test/fixtures),
# nicht diese Seeds. Der Aufruf ist idempotent (find_or_create_by).
#
#   bin/rails db:seed
#   SEED_PRODUCTS=5000 bin/rails db:seed   # zusätzlich 5'000 generierte Produkte (Q4)

DEMO_PASSWORD = "probiert-demo-2026"

puts "Benutzer…"
users = {
  anna:  { name: "Anna Keller",  email_address: "anna@example.test",  role: :benutzer },
  ben:   { name: "Ben Meier",    email_address: "ben@example.test",   role: :benutzer },
  clara: { name: "Clara Huber",  email_address: "clara@example.test", role: :benutzer },
  moni:  { name: "Moni Steiner", email_address: "moni@example.test",  role: :moderator },
  max:   { name: "Max Brunner",  email_address: "max@example.test",   role: :moderator },
  admin: { name: "Admin",        email_address: "admin@example.test", role: :administrator }
}.transform_values do |attrs|
  User.find_or_create_by!(email_address: attrs[:email_address]) do |u|
    u.assign_attributes(attrs.merge(password: DEMO_PASSWORD, password_confirmation: DEMO_PASSWORD))
  end
end

puts "Stammdaten…"
categories = %w[Aufstriche Saucen Milchprodukte Snacks Getränke Fertiggerichte].index_with do |name|
  Category.find_or_create_by!(name:)
end
chains = %w[Migros Coop Aldi Lidl].index_with do |name|
  RetailChain.find_or_create_by!(name:)
end

puts "Produkte…"
# Bezeichnung, Marke, Kategorie, Handelskette, erfassende Person, Beschreibung
products_data = [
  [ "Hummus Classic", "M-Classic", "Aufstriche", "Migros", :anna,
    "Cremiger Kichererbsen-Aufstrich mit Sesampaste und einem Spritzer Zitrone. 200-g-Becher aus dem Kühlregal." ],
  [ "Hummus Natur", "Qualité & Prix", "Aufstriche", "Coop", :ben,
    "Klassischer Hummus ohne Zusätze, mild gewürzt. Die günstigste Variante im Sortiment." ],
  [ "Hummus", "Bio", "Aufstriche", "Aldi", :clara,
    "Bio-Hummus aus biologischem Anbau im 175-g-Becher. Etwas fester als die übrigen." ],
  [ "Hummus Paprika", "Lidl Bio", "Aufstriche", "Lidl", :anna,
    "Hummus mit gerösteter Paprika, leicht rauchig im Geschmack. Bio-Qualität." ],
  [ "Pesto Verde", "M-Classic", "Saucen", "Migros", :ben,
    "Basilikumpesto mit Cashewkernen und Hartkäse im 190-g-Glas. Reicht für zwei Portionen Pasta." ],
  [ "Pesto alla Genovese", "Fine Food", "Saucen", "Coop", :anna,
    "Pesto mit Pinienkernen und Basilikum aus Ligurien. Premiumlinie, entsprechend teurer." ],
  [ "Chili Sauce", "Prix Garantie", "Saucen", "Coop", :clara,
    "Scharfe Chilisauce in der Quetschflasche, süss-sauer abgeschmeckt." ],
  [ "Tomatensauce Basilico", "Cucina", "Saucen", "Aldi", :ben,
    "Passierte Tomaten mit Basilikum, ohne Zuckerzusatz. 350-g-Glas." ],
  [ "Bio Joghurt Nature", "Migros Bio", "Milchprodukte", "Migros", :anna,
    "Naturjoghurt aus Bio-Vollmilch im 500-g-Becher. Ohne Zucker und ohne Aromen." ],
  [ "Griechischer Joghurt", "Milbona", "Milchprodukte", "Lidl", :clara,
    "Cremiger Joghurt nach griechischer Art mit 10 % Fett. Auch zum Kochen geeignet." ],
  [ "Mozzarella", "Qualité & Prix", "Milchprodukte", "Coop", :ben,
    "Mozzarella im Wasserbad, 150 g Abtropfgewicht. Für Caprese und Pizza." ],
  [ "Chips Paprika", "Zweifel", "Snacks", "Migros", :anna,
    "Paprikachips aus Schweizer Kartoffeln im 175-g-Beutel." ],
  [ "Nachos Cheese", "Snack Day", "Snacks", "Lidl", :ben,
    "Maischips mit Käsegeschmack. Passen zu Dip und Guacamole." ],
  [ "Salznüsse", "Sun Queen", "Snacks", "Migros", :clara,
    "Geröstete und gesalzene Erdnüsse in der 200-g-Packung." ],
  [ "Eistee Pfirsich", "Kult", "Getränke", "Migros", :anna,
    "Eistee mit Pfirsichgeschmack in der 1,5-Liter-Flasche." ],
  [ "Cola Zero", "Prix Garantie", "Getränke", "Coop", :ben,
    "Koffeinhaltiges Erfrischungsgetränk ohne Zucker, 1,5 Liter." ],
  [ "Apfelschorle", "Rivella", "Getränke", "Aldi", :clara,
    "Apfelsaftschorle mit Mineralwasser, 50 % Fruchtgehalt." ],
  [ "Lasagne Bolognese", "Anna's Best", "Fertiggerichte", "Migros", :anna,
    "Fertiglasagne mit Rindfleischsauce und Béchamel für zwei Personen. 15 Minuten in den Ofen." ],
  [ "Pizza Margherita", "Betty Bossi", "Fertiggerichte", "Coop", :ben,
    "Steinofenpizza mit Tomatensauce und Mozzarella aus der Kühltheke." ],
  [ "Curry Chicken", "Vitasia", "Fertiggerichte", "Lidl", :clara,
    "Hähnchencurry mit Basmatireis in der 400-g-Schale für die Mikrowelle." ]
]
products = products_data.map do |name, brand, category, chain, creator, description|
  product = Product.create_with(created_by: users[creator], category: categories[category])
                   .find_or_create_by!(name_normalized: Product.normalize(name),
                                       brand_normalized: Product.normalize(brand),
                                       retail_chain: chains[chain]) do |p|
    p.name = name
    p.brand = brand
  end

  # Auch bei bestehenden Einträgen nachziehen, damit ein erneutes Seeden
  # geänderte Demo-Texte tatsächlich übernimmt.
  product.update!(description:) if product.description != description
  product
end

puts "Bewertungen…"
comments = {
  5 => [ "Cremig, gut gewürzt, kaufe ich wieder.", "Bestes Produkt in dieser Kategorie.", "Schmeckt wie selbst gemacht." ],
  4 => [ "Gut, etwas teuer.", "Solide, würde ich wieder nehmen.", nil ],
  3 => [ "Okay, nichts Besonderes.", nil ],
  2 => [ "Zu sauer für meinen Geschmack.", "Künstlicher Nachgeschmack." ],
  1 => [ "Leider ungeniessbar.", "Wer das kauft, ist selber schuld." ]
}
rng = Random.new(223)
raters = users.values_at(:anna, :ben, :clara, :moni)
products.each do |product|
  raters.sample(rng.rand(1..4), random: rng).each do |user|
    stars = [ 5, 5, 4, 4, 4, 3, 3, 2, 1 ].sample(random: rng)
    Rating.find_or_create_by!(user:, product:) do |r|
      r.stars = stars
      r.comment = comments[stars].sample(random: rng)
    end
  end
  product.recalculate_aggregates!
end

puts "Meldungen…"
reportable = Rating.where(stars: [ 1, 2 ]).where.not(user: users[:ben]).limit(2)
reportable.each do |rating|
  Report.find_or_create_by!(rating:, reporter: users[:ben]) { |r| r.reason = :spam }
end

if (n = ENV["SEED_PRODUCTS"].to_i).positive?
  puts "#{n} generierte Produkte für den Performance-Test…"
  adjectives = %w[Bio Classic Premium Fine Natur Light Original Rustico Deluxe Fresh]
  nouns = %w[Aufstrich Sauce Joghurt Snack Getränk Pasta Suppe Müesli Riegel Dip Käse Brot Konfitüre Tee Kaffee]
  now = Time.current
  rows = n.times.map do |i|
    name = "#{adjectives[i % adjectives.size]} #{nouns[(i / adjectives.size) % nouns.size]} #{i}"
    brand = "Marke #{i % 97}"
    {
      name:, brand:,
      name_normalized: Product.normalize(name), brand_normalized: Product.normalize(brand),
      category_id: categories.values[i % categories.size].id,
      retail_chain_id: chains.values[i % chains.size].id,
      created_by_id: users[:anna].id,
      created_at: now, updated_at: now
    }
  end
  Product.insert_all(rows, unique_by: :index_products_on_normalized_identity)
end

puts "Fertig. Demo-Konten (Passwort «#{DEMO_PASSWORD}»):"
users.each_value { |u| puts "  #{u.email_address.ljust(22)} #{u.role}" }
