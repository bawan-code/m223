require "test_helper"

# Projektregel: keine Browser-Dialoge (window.confirm). Sie lassen sich nicht
# gestalten, sind nicht übersetzbar und fallen ohne JavaScript ersatzlos aus –
# eine gefährliche Aktion wäre dann ungeschützt. Gefährliche Aktionen bekommen
# stattdessen eine eigene Bestätigungsseite, die serverseitig wirkt.
class NoBrowserDialogsTest < ActionDispatch::IntegrationTest
  test "keine Ansicht verwendet einen Browser-Dialog" do
    views = Dir[Rails.root.join("app/views/**/*.erb")]
    offenders = views.select { |view| File.read(view).match?(/turbo_confirm|turbo-confirm/) }

    assert_empty offenders.map { |view| Pathname(view).relative_path_from(Rails.root).to_s },
                 "gefährliche Aktionen brauchen eine Bestätigungsseite, keinen window.confirm"
  end
end
