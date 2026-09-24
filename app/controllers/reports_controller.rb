# F7, Benutzerseite: eine fremde Bewertung melden (Screen 6).
class ReportsController < ApplicationController
  before_action :set_rating

  # Die Policy verbietet das Melden der eigenen Bewertung und eine zweite
  # Meldung derselben Bewertung. Beides ist ein Zustand, den der Benutzer
  # versteht und nicht ändern kann – deshalb hier eine Erklärung statt der
  # 403-Seite. Abgewiesen wird der Versuch trotzdem serverseitig.
  rescue_from Pundit::NotAuthorizedError, with: :explain_refusal

  def new
    @report = @rating.reports.new(reporter: Current.user)
    authorize @report
  end

  def create
    @report = @rating.reports.new(report_params.merge(reporter: Current.user))
    authorize @report

    if @report.save
      redirect_to @rating.product, notice: t("reports.created")
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to @rating.product, alert: t("reports.already_reported")
  end

  private

  def set_rating
    @rating = Rating.find(params[:rating_id])
  end

  def report_params
    params.expect(report: [ :reason ])
  end

  def explain_refusal
    message = if @rating.user_id == Current.user&.id
      t("reports.own_rating")
    else
      t("reports.already_reported")
    end

    redirect_to @rating.product, alert: message
  end
end
