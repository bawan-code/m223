// Einstiegspunkt der Importmap (config/importmap.rb).
//
// Turbo übernimmt Seitenwechsel und Formulare ohne vollen Reload und wertet
// data-turbo-confirm bei gefährlichen Aktionen aus. Stimulus ist nicht im
// Einsatz; eigenes JavaScript gibt es nur für den Effekt-Schalter unten.
import "@hotwired/turbo-rails"

// Hintergrund-Effekte ein- und ausschalten. Die Klasse sitzt auf <html>, das
// Turbo beim Seitenwechsel behält; die Wahl merkt sich der Browser.
function applyEffects(on) {
  document.documentElement.classList.toggle("fx-on", on)
  document.querySelector(".fx-switch")?.setAttribute("aria-pressed", on)
}

addEventListener("turbo:load", () => applyEffects(localStorage.getItem("fx") !== "off"))

addEventListener("click", ({ target }) => {
  if (!target.closest(".fx-switch")) return

  const on = !document.documentElement.classList.contains("fx-on")
  localStorage.setItem("fx", on ? "on" : "off")
  applyEffects(on)
})
