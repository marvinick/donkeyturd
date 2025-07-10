class CitiesController < ApplicationController
  before_action :set_city, only: [:show, :view_type]
  
  def index
    # Filter by country if specified
    if params[:country].present?
      @cities = City.with_listings.where(country: params[:country]).alphabetical
      @current_country = params[:country]
      @page_title = "Best Views in #{params[:country]} - Scenic Accommodations"
      @page_description = "Discover amazing properties with stunning views across #{params[:country]}. Browse cities and find your perfect scenic getaway."
    else
      @cities = City.with_listings.alphabetical.limit(100)
      @page_title = "Browse Amazing Views by City - Discover Scenic Accommodations Worldwide"
      @page_description = "Explore stunning accommodations with breathtaking views in cities around the world. Find your perfect scenic getaway."
    end
    
    @featured_cities = City.featured.with_listings.by_listings_count.limit(8)
    @countries = City.with_listings.distinct.pluck(:country).sort
    @total_cities = City.with_listings.count
    @total_listings = Listing.active.count
    
    # SEO data
    @meta_title = @page_title
    @meta_description = @page_description
    @canonical_url = request.original_url
    
    # Schema.org data
    @schema_data = {
      "@context" => "https://schema.org",
      "@type" => "CollectionPage",
      "name" => @page_title,
      "description" => @page_description,
      "url" => @canonical_url,
      "about" => {
        "@type" => "TravelAction",
        "name" => "City Travel Guide"
      }
    }
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
    @page = params[:page].to_i > 0 ? params[:page].to_i : 1
    @per_page = 12
    @offset = (@page - 1) * @per_page
    @total_listings = @listings.count
    @total_pages = (@total_listings.to_f / @per_page).ceil
    @listings = @listings.limit(@per_page).offset(@offset)
    
    # Related data
    @view_types_in_city = @city.listings_by_view_type
    @featured_listings = @city.featured_listings(6)
    @nearby_cities = @city.nearby_cities(100)
    @all_listings_for_map = @city.listings.active.with_coordinates
    
    # Dynamic SEO based on filters
    @meta_title = build_city_meta_title
    @meta_description = build_city_meta_description
    @meta_keywords = @city.seo_keywords
    @canonical_url = build_canonical_url
    
    # Breadcrumbs
    @breadcrumbs = build_breadcrumbs
    
    # FAQ data for SEO
    @faq_data = build_city_faq_data
    
    # Schema.org structured data
    @schema_data = build_city_schema_data
  end
  
  # View type specific pages: /cities/banff-alberta/mountain-views
  def view_type
    @view_type = params[:view_type]
    
    unless Listing::VIEW_TYPES.include?(@view_type)
      redirect_to city_path(@city) and return
    end
    
    @listings = @city.listings.active.where(view_type: @view_type)
                     .includes(:user, images_attachments: :blob)
    
    # Pagination for view type pages
    @page = params[:page].to_i > 0 ? params[:page].to_i : 1
    @per_page = 12
    @offset = (@page - 1) * @per_page
    @total_listings = @listings.count
    @total_pages = (@total_listings.to_f / @per_page).ceil
    @listings = @listings.limit(@per_page).offset(@offset)
    
    @related_view_types = @city.listings_by_view_type.except(@view_type).keys.first(5)
    @other_cities_with_view_type = City.joins(:listings)
                                      .where(listings: { view_type: @view_type, active: true })
                                      .where.not(id: @city.id)
                                      .group('cities.id')
                                      .order('COUNT(listings.id) DESC')
                                      .limit(5)
    
    # SEO for view type pages
    @meta_title = "#{@view_type.humanize} Views in #{@city.display_name} - #{@total_listings} Scenic Properties"
    @meta_description = "Discover #{@total_listings} properties with stunning #{@view_type} views in #{@city.display_name}. Compare prices and book your perfect #{@view_type} view accommodation."
    @canonical_url = view_type_city_url(@city, @view_type)
    
    # View type specific schema
    @schema_data = {
      "@context" => "https://schema.org",
      "@type" => "CollectionPage",
      "name" => @meta_title,
      "description" => @meta_description,
      "url" => @canonical_url,
      "about" => {
        "@type" => "LodgingBusiness",
        "name" => "#{@view_type.humanize} View Accommodations"
      }
    }
    
    render :view_type
  end
  
  private
  
  def set_city
    @city = City.find_by!(slug: params[:id] || params[:city_slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to cities_path, alert: "City not found"
  end
  
  def build_city_meta_title
    if @current_view_type
      "#{@current_view_type.humanize} Views in #{@city.display_name} - #{@total_listings} Properties"
    elsif @current_platform
      "#{@current_platform.humanize} Properties in #{@city.display_name} - Stunning Views"
    else
      @city.seo_title
    end
  end
  
  def build_city_meta_description
    if @current_view_type
      "Find #{@total_listings} properties with amazing #{@current_view_type} views in #{@city.display_name}. Compare prices and book your perfect scenic getaway."
    elsif @current_platform
      "Browse #{@total_listings} #{@current_platform.humanize} properties with stunning views in #{@city.display_name}. Book verified accommodations with breathtaking vistas."
    else
      @city.seo_description
    end
  end
  
  def build_canonical_url
    if @current_view_type
      view_type_city_url(@city, @current_view_type)
    elsif @current_platform
      city_url(@city, platform: @current_platform)
    else
      city_url(@city)
    end
  end
  
  def build_breadcrumbs
    breadcrumbs = [
      { name: 'Home', url: root_path },
      { name: 'Cities', url: cities_path }
    ]
    
    if @city.country != @city.display_name
      breadcrumbs << { name: @city.country, url: cities_path(country: @city.country) }
    end
    
    breadcrumbs << { name: @city.display_name, url: city_path(@city) }
    
    if @current_view_type
      breadcrumbs << { name: "#{@current_view_type.humanize} Views", url: nil }
    end
    
    breadcrumbs
  end
  
  def build_city_faq_data
    [
      {
        question: "How many properties with views are available in #{@city.display_name}?",
        answer: "Currently, there are #{@total_listings} verified properties offering stunning views in #{@city.display_name}."
      },
      {
        question: "What types of views can I find in #{@city.display_name}?",
        answer: "In #{@city.display_name}, you can find properties with #{@view_types_in_city.keys.map(&:humanize).join(', ')} views."
      },
      {
        question: "How do I book a property with views in #{@city.display_name}?",
        answer: "You can book directly through the property's listing on platforms like Airbnb, Booking.com, VRBO, and others. Each listing includes a direct booking link."
      },
      {
        question: "Are the view properties in #{@city.display_name} verified?",
        answer: "Yes, all properties on our platform are manually reviewed and verified to ensure they actually offer the advertised views."
      }
    ]
  end
  
  def build_city_schema_data
    {
      "@context" => "https://schema.org",
      "@type" => ["Place", "City"],
      "name" => @city.display_name,
      "description" => @meta_description,
      "url" => @canonical_url,
      "geo" => {
        "@type" => "GeoCoordinates",
        "latitude" => @city.latitude,
        "longitude" => @city.longitude
      },
      "containsPlace" => @listings.limit(5).map do |listing|
        {
          "@type" => "LodgingBusiness",
          "name" => listing.title,
          "description" => listing.description.truncate(160),
          "url" => listing_url(listing)
        }
      end
    }
  end
end
