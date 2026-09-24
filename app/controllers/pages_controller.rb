class PagesController < ApplicationController
  include SkipAuthorization
  allow_unauthenticated_access

  def home
  end
end
