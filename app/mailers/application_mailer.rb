class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"

  private

  # In der Entwicklung wird nichts verschickt (delivery_method :test). Damit der
  # Link trotzdem erreichbar ist, schreiben ihn die Mailer als eigene, ungekürzte
  # Zeile ins Log. Nicht aus dem Mail-Text kopieren: der ist quoted-printable
  # codiert und bricht lange Zeilen mit einem "=" am Zeilenende um – der Token
  # wäre dadurch kaputt.
  #
  #   grep "^--> " log/development.log | tail -1
  def log_link(label, url)
    Rails.logger.info "\n--> #{label}\n--> #{url}\n"
  end
end
