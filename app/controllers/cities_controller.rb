class CitiesController < ApplicationController
  before_action :set_city, only: [:show]
  
  def index
    @featured_cities = City.featured.with_listings.by_listings_count.limit(8)
    @all_cities = City.with_listings.alphabetical.limit(50)
    @countries = City.with_listings.distinct.pluck(:country).sort
    
    # SEO meta tags
    @meta_title = "Browse Amazing Views by City - Discover Scenic Accommodations Worldwide"
    @meta_description = "Explore stunning accommodations with breathtaking views in cities around the world. Find your perfect scenic getaway."
  end

  def show
    @listings = @city.listings.active.includes(:user, images_attachments: :blob)
    
    # Filter by view type if specified
    if params[:view_type].present? && Listing::VIEW_TYPES.include?(params[:view_type])
      @listings = @listings.where(view_type: params[:view_type])
      @current_view_type = params[:view_type]
    end
    
    # Filter by platform if specified  
    if params[:platform].present? && Listing::PLATFORMS.include?(params[:platform])
      @listings = @listings.where(platform: params[:platform])
      @current_platform = params[:platform]
    end
    
    # Pagination
    @listings = @listings.limit(12).offset((params[:page].to_i - 1) * 12) if params[:page].present?
    @listings = @listings.limit(12) if params[:page].blank?
    
    # Related data
    @view_types_in_city = @city.listings_by_view_type
    @featured_listings = @city.featured_listings(6)
    @nearby_cities = @city.nearby_cities(100)
    @all_listings_for_map = @city.listings.active.with_coordinates
    
    # SEO meta tags
    @meta_title = @city.seo_title
    @meta_description = @city.seo_description
    @meta_keywords = @city.seo_keywords
    
    # Breadcrumbs
    @breadcrumbs = [
      { name: 'Home', url: root_path },
      { name: 'Cities', url: cities_path },
      { name: @city.country, url: cities_path(country: @city.country) },
      { name: @city.display_name, url: nil }
    ]
  end
  
  # View type specific pages: /cities/banff-alberta/mountain-views
  def view_type
    @city = City.find_by!(slug: params[:city_slug])
    @view_type = params[:view_type]
    
    unless Listing::VIEW_TYPES.include?(@view_type)
      redirect_to city_path(@city) and return
    end
    
    @listings = @city.listings.active.where(view_type: @view_type)
                     .includes(:user, images_attachments: :blob)
                     .limit(12)
    
    @related_view_types = @city.listings_by_view_type.except(@view_type).keys.first(3)
    
    # SEO for view type pages
    @meta_title = "#{@view_type.humanize} Views in #{@city.display_name} - Best Scenic Accommodations"
    @meta_description = "Discover #{@listings.count}+ properties with stunning #{@view_type} views in #{@city.display_name}. Book your perfect scenic getaway today."
    
    render :view_type
  end
  
  private
  
  def set_city
    @city = City.find_by!(slug: params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to cities_path, alert: "City not found"
  end
end
