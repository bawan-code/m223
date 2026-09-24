# Basis aller Policies. `user` ist Current.user und kann nil sein (Gast) –
# jede Policy muss diesen Fall behandeln, sonst schlägt eine öffentliche Seite
# mit NoMethodError fehl statt mit einer sauberen Berechtigungsprüfung.
# Standard ist überall "verboten"; jede Policy erlaubt einzeln.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def new? = create?
  def update? = false
  def edit? = update?
  def destroy? = false

  private

  def angemeldet? = user.present?
  def moderator_or_admin? = user&.moderator_or_admin? || false
  def administrator? = user&.administrator? || false

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
