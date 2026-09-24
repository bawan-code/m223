ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Ersetzt eine Klassenmethode für die Dauer des Blocks, sodass sie den
    # angegebenen Fehler wirft. Damit lassen sich Gleichzeitigkeitsfälle
    # auslösen, die sich in einem einzelnen Testprozess sonst nicht herstellen
    # lassen – etwa ein Unique-Index, der zuschlägt, nachdem die Validierung
    # bereits zufrieden war.
    def raising(klass, method, error, message = "simulierter Gleichzeitigkeitsfall")
      original = klass.method(method)
      klass.define_singleton_method(method) { |*| raise error, message }
      yield
    ensure
      klass.define_singleton_method(method, original)
    end
  end
end
