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
  scope :with_listings, -> { where('listings_count > 0') }
  scope :alphabetical, -> { order(:name) }
  scope :by_listings_count, -> { order(listings_count: :desc) }
  
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
          "6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude))) < ?",
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
end
