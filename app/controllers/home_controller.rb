class HomeController < ApplicationController
  # Allow homepage to be viewed without authentication
  # We'll add authentication requirements to other actions as needed
  
  def index
    @featured_listings = []
    # TODO: Add featured listings logic
  end
end
