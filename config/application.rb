require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module M223
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # PaperTrail legt die Versionen als YAML ab. Rails erlaubt beim Lesen nur
    # ausdrücklich zugelassene Klassen; ohne Zeitstempel und Symbole bliebe
    # `version.changeset` stumm leer und das Protokoll zeigte keine Felder.
    # Symbol ist der Rails-Standard, die übrigen kommen in Zeitstempeln und
    # Zahlenfeldern der Versionen vor.
    config.active_record.yaml_column_permitted_classes = [
      Symbol, Date, Time, DateTime, BigDecimal, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone
    ]

    config.time_zone = "Bern"
    config.i18n.default_locale = :de
    config.i18n.available_locales = [ :de, :en ]
  end
end
