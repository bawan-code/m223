# Q4: Performance der Produktsuche.
#
# Anforderung (Projektantrag 4.2): Bei 5'000 erfassten Produkten und zehn
# gleichzeitigen Suchanfragen liefert die Produktsuche das Ergebnis in
# höchstens zwei Sekunden (95. Perzentil).
#
# Gemessen werden vollständige Requests auf /products – inklusive Routing,
# Policy-Scope, Abfrage und Rendern der Trefferliste. Eine reine
# SQL-Messung wäre optimistischer als das, was der Benutzer erlebt.
#
# Ausführen auf einer eigenen Datenbank, damit die Entwicklungsdaten sauber
# bleiben:
#
#   export DATABASE_URL="sqlite3:storage/benchmark.sqlite3"
#   bin/rails db:prepare
#   SEED_PRODUCTS=5000 bin/rails db:seed
#   bin/rails runner script/search_benchmark.rb
#   rm storage/benchmark.sqlite3*

THREADS = 10
REQUESTS_PER_THREAD = 10
QUERIES = [
  "/products",
  "/products?q=bio",
  "/products?q=sauce",
  "/products?q=marke+42",
  "/products?q=joghurt&category_id=",
  "/products?q=hummus"
].freeze

if Product.count < 5000
  abort "Nur #{Product.count} Produkte vorhanden. Zuerst: SEED_PRODUCTS=5000 bin/rails db:seed"
end

# Log-Ausgaben verfälschen die Messung deutlich mehr als die Suche selbst.
Rails.logger.level = Logger::ERROR

# In der Entwicklung lässt Rails nur bekannte Hosts zu; der Standardwert einer
# Integration-Session wäre www.example.com und würde mit 403 abgewiesen.
def new_session
  ActionDispatch::Integration::Session.new(Rails.application).tap { |session| session.host!("localhost") }
end

def request_once(session, path)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  session.get(path)
  raise "#{path} antwortete mit #{session.response.status}" unless session.response.status == 200

  Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
end

puts "#{Product.count} Produkte, #{THREADS} gleichzeitige Threads, " \
     "#{THREADS * REQUESTS_PER_THREAD} Anfragen"

# Aufwärmen: der erste Request zahlt das Laden der Klassen und Views.
request_once(new_session, QUERIES.first)

durations = THREADS.times.map do |thread_number|
  Thread.new do
    session = new_session

    REQUESTS_PER_THREAD.times.map do |request_number|
      request_once(session, QUERIES[(thread_number + request_number) % QUERIES.size])
    end
  end
end.flat_map(&:value).sort

def percentile(sorted, fraction)
  sorted[(sorted.size * fraction).ceil - 1]
end

puts format("Median      %6.0f ms", percentile(durations, 0.50) * 1000)
puts format("95. Perzentil %4.0f ms", percentile(durations, 0.95) * 1000)
puts format("Maximum     %6.0f ms", durations.last * 1000)
puts
puts percentile(durations, 0.95) <= 2.0 ? "Q4 erfüllt (Grenzwert 2000 ms)" : "Q4 VERFEHLT"
