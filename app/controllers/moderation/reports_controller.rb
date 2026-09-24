# F7, Moderatorseite: Meldungen übernehmen und entscheiden (Screens 7 und 8).
module Moderation
  class ReportsController < ApplicationController
    before_action :set_report, except: :index

    # «Übernehmen» kann daran scheitern, dass eine Kollegin schneller war – das
    # ist ein Zustand, kein fehlendes Recht (Screen 7). Jede andere Ablehnung,
    # etwa der Zugriff auf eine fremde Meldung, bleibt ein 403.
    rescue_from Pundit::NotAuthorizedError do |error|
      if action_name == "claim" && Current.user&.moderator_or_admin? && @report&.claimed?
        already_claimed(@report.moderator)
      else
        forbidden
      end
    end

    # Drei Listen: frei, von mir übernommen, von anderen übernommen (Screen 7).
    def index
      # Die Liste selbst ist ein Privileg – ein leerer Scope allein würde die
      # Seite für alle erreichbar lassen.
      authorize Report

      reports = policy_scope(Report).includes(:moderator, rating: %i[ user product ])

      @open_reports = reports.offen.newest_first
      @my_reports = reports.claimed_by(Current.user).newest_first
      @other_reports = reports.in_bearbeitung.where.not(moderator: Current.user).newest_first
      @decided_reports = reports.where(status: %i[ freigegeben gesperrt ]).newest_first.limit(20)
    end

    def show
      authorize @report
    end

    # Pessimistische Sperre: Es gewinnt genau eine Moderatorin.
    def claim
      authorize @report
      @report.claim!(Current.user)
      redirect_to moderation_report_path(@report), notice: t("moderation.claimed")
    rescue Report::AlreadyClaimed => e
      # Gleicher Ausgang, andere Ursache: hier war die Meldung beim Prüfen noch
      # frei und wurde erst innerhalb der Transaktion vergeben.
      already_claimed(e.moderator)
    end

    def unclaim
      authorize @report
      @report.unclaim!
      redirect_to moderation_reports_path, notice: t("moderation.unclaimed")
    end

    # Entscheidung: Bewertung bleibt stehen
    def release
      authorize @report
      @report.release!
      redirect_to moderation_reports_path, notice: t("moderation.released")
    end

    # Entscheidung: Bewertung wird gesperrt, Aggregate des Produkts nachgeführt
    def block
      authorize @report
      @report.block!
      redirect_to moderation_reports_path, notice: t("moderation.blocked")
    end

    private

    def set_report
      @report = Report.find(params[:id])
    end

    def already_claimed(moderator)
      redirect_to moderation_reports_path, alert: t("moderation.already_claimed", name: moderator&.name)
    end
  end
end
