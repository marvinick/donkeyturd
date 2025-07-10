class City < ApplicationRecord
  has_many :listings, dependent: :nullify
  
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :country, presence: true
  validates :latitude, presence: true, numericality: { in: -90..90 }
  validates :longitude, presence: true, numericality: { in: -180..180 }
  
  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  
  scope :featured, -> { where(featured: true) }
  scope :by_country, ->(country) { where(country: country) }
  scope :with_listings, -> { joins(:listings).where(listings: { active: true }).distinct }
  scope :alphabetical, -> { order(:name) }
  scope :by_listings_count, -> { order(listings_count: :desc) }
  
  # Add method to find cities near coordinates
  scope :near_coordinates, ->(lat, lng, radius_km = 50) {
    where(
      "6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude))) < ?",
      lat, lng, lat, radius_km
    ).order(
      Arel.sql("6371 * acos(cos(radians(#{lat})) * cos(radians(latitude)) * cos(radians(longitude) - radians(#{lng})) + sin(radians(#{lat})) * sin(radians(latitude)))")
    )
  }
  
  # SEO Methods
  def to_param
    slug
  end
  
  def display_name
    if state_province.present?
      "#{name}, #{state_province}"
    else
      "#{name}, #{country}"
    end
  end
  
  def full_display_name
    parts = [name]
    parts << state_province if state_province.present?
    parts << country
    parts.join(', ')
  end
  
  def seo_title
    "Best Views in #{display_name} - Stunning Accommodations with Amazing Views"
  end
  
  def seo_description
    count_text = listings_count > 0 ? "Browse #{listings_count} verified properties" : "Discover amazing properties"
    "#{count_text} with breathtaking views in #{display_name}. Find the perfect accommodation with stunning vistas for your next getaway."
  end
  
  def seo_keywords
    keywords = [name, country]
    keywords << state_province if state_province.present?
    keywords += ['views', 'accommodation', 'vacation rental', 'scenic', 'beautiful']
    keywords.join(', ')
  end
  
  # Geographic methods
  def has_coordinates?
    latitude.present? && longitude.present?
  end
  
  def nearby_cities(radius_km = 100)
    return City.none unless has_coordinates?
    
    City.where.not(id: id)
        .where(
          "6371 * acos(cos(radians(?)) * cos(radians(cities.latitude)) * cos(radians(cities.longitude) - radians(?)) + sin(radians(?)) * sin(radians(cities.latitude))) < ?",
          latitude, longitude, latitude, radius_km
        )
        .with_listings
        .limit(5)
  end
  
  # Listing statistics
  def listings_by_view_type
    listings.group(:view_type).count
  end
  
  def top_view_types(limit = 3)
    listings_by_view_type.sort_by { |_, count| -count }.first(limit).map(&:first)
  end
  
  def featured_listings(limit = 6)
    listings.active.verified.limit(limit)
  end
  
  def recent_listings(limit = 6)
    listings.active.recent.limit(limit)
  end
  
  # Content generation helpers
  def primary_view_type
    top_view_types(1).first&.humanize || 'Scenic'
  end
  
  def listings_summary
    return "No listings yet" if listings_count.zero?
    
    view_types = top_view_types.map(&:humanize).join(', ')
    "#{listings_count} properties featuring #{view_types} views"
  end
  
  # Advanced SEO content generation
  def generate_view_type_content(view_type)
    count = listings.where(view_type: view_type).count
    return nil if count.zero?
    
    {
      title: "#{view_type.humanize} Views in #{display_name}",
      description: "Discover #{count} stunning properties with #{view_type} views in #{display_name}. Each accommodation offers breathtaking #{view_type} vistas for an unforgettable stay.",
      content: generate_view_type_description(view_type, count),
      count: count
    }
  end
  
  def all_view_types_content
    listings_by_view_type.map do |view_type, count|
      {
        view_type: view_type,
        humanized: view_type.humanize,
        count: count,
        url_slug: "#{view_type}-views",
        description: "#{count} properties with #{view_type} views"
      }
    end.sort_by { |item| -item[:count] }
  end
  
  def generate_destination_guide
    {
      title: "#{display_name} Travel Guide - Best Views & Scenic Accommodations",
      intro: generate_intro_content,
      highlights: generate_highlights,
      best_time_to_visit: generate_best_time_content,
      view_types_overview: all_view_types_content,
      nearby_destinations: nearby_cities.map { |city| { name: city.display_name, slug: city.slug, count: city.listings_count } }
    }
  end
  
  private
  
  def generate_slug
    base_slug = name.downcase.gsub(/[^a-z0-9\s-]/, '').gsub(/\s+/, '-')
    
    # Add state/country if needed for uniqueness
    if state_province.present?
      self.slug = "#{base_slug}-#{state_province.downcase.gsub(/[^a-z0-9\s-]/, '').gsub(/\s+/, '-')}"
    else
      self.slug = "#{base_slug}-#{country.downcase.gsub(/[^a-z0-9\s-]/, '').gsub(/\s+/, '-')}"
    end
    
    # Ensure uniqueness
    counter = 1
    original_slug = slug
    while City.exists?(slug: slug)
      self.slug = "#{original_slug}-#{counter}"
      counter += 1
    end
  end
  
  def generate_view_type_description(view_type, count)
    case view_type
    when 'mountain'
      "Experience breathtaking mountain vistas from #{count} carefully selected accommodations in #{display_name}. Wake up to snow-capped peaks and alpine scenery that will leave you speechless."
    when 'ocean'
      "Enjoy stunning ocean views from #{count} beachfront and coastal properties in #{display_name}. Fall asleep to the sound of waves and wake up to endless blue horizons."
    when 'lake'
      "Discover #{count} lakefront accommodations in #{display_name} offering serene water views and peaceful surroundings perfect for relaxation and reflection."
    when 'city'
      "Take in dynamic city skylines from #{count} urban accommodations in #{display_name}. Experience the energy of the city while enjoying elevated views of the metropolitan landscape."
    when 'forest'
      "Immerse yourself in nature with #{count} forest view properties in #{display_name}. Surrounded by lush greenery and wildlife, these accommodations offer a true escape into nature."
    when 'desert'
      "Experience the stark beauty of desert landscapes from #{count} unique accommodations in #{display_name}. Witness stunning sunrises and sunsets across vast, open terrain."
    when 'river'
      "Enjoy peaceful river views from #{count} waterfront properties in #{display_name}. Listen to flowing water while taking in scenic riverbank landscapes."
    when 'canyon'
      "Marvel at dramatic canyon vistas from #{count} strategically located accommodations in #{display_name}. Experience the grandeur of ancient geological formations."
    when 'valley'
      "Take in sweeping valley views from #{count} elevated accommodations in #{display_name}. Enjoy panoramic vistas of rolling landscapes and natural beauty."
    when 'beach'
      "Relax with pristine beach views from #{count} coastal accommodations in #{display_name}. Enjoy direct beach access and stunning shoreline vistas."
    else
      "Discover #{count} properties with stunning #{view_type} views in #{display_name}, each offering unique perspectives of the local landscape."
    end
  end
  
  def generate_intro_content
    "#{display_name} offers some of the most spectacular scenic accommodations in #{country}. With #{listings_count} verified properties featuring #{top_view_types.map(&:humanize).join(', ')} views, this destination provides diverse options for travelers seeking breathtaking vistas and memorable experiences."
  end
  
  def generate_highlights
    highlights = ["#{listings_count} verified properties with stunning views"]
    
    if top_view_types.any?
      highlights << "Specializing in #{top_view_types.first.humanize.downcase} views"
    end
    
    if nearby_cities.any?
      highlights << "Close to #{nearby_cities.count} other scenic destinations"
    end
    
    highlights << "Properties available on major booking platforms"
    highlights << "Hand-picked accommodations for quality assurance"
    
    highlights
  end
  
  def generate_best_time_content
    "#{display_name} offers beautiful views year-round, with each season providing unique perspectives of the landscape. Consider visiting during different times of the year to experience varying weather conditions and seasonal changes that enhance the natural beauty of your chosen accommodation's views."
  end
end
