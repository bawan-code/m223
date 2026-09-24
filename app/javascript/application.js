// Einstiegspunkt der Importmap (config/importmap.rb).
//
// Turbo übernimmt Seitenwechsel und Formulare ohne vollen Reload und wertet
// data-turbo-confirm bei gefährlichen Aktionen aus. Stimulus ist noch nicht
// im Einsatz; die Applikation kommt bisher ohne eigenes JavaScript aus.
import "@hotwired/turbo-rails"
