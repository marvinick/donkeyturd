class Listing < ApplicationRecord
  belongs_to :user
  has_many_attached :images

  # Constants for validation
  PLATFORMS = %w[airbnb booking_com vrbo hotels_com expedia kayak other].freeze
  VIEW_TYPES = %w[mountain ocean lake city desert forest river canyon valley beach].freeze
  PRICE_RANGES = ['$0-$50', '$51-$100', '$101-$200', '$201-$300', '$301-$500', '$500+'].freeze

  # Validations
  validates :title, presence: true, length: { minimum: 10, maximum: 100 }
  validates :description, presence: true, length: { minimum: 50, maximum: 1000 }
  validates :external_url, presence: true, uniqueness: true
  validates :platform, presence: true, inclusion: { in: PLATFORMS }
  validates :location, presence: true, length: { minimum: 3, maximum: 100 }
  validates :view_type, presence: true, inclusion: { in: VIEW_TYPES }
  validates :price_range, inclusion: { in: PRICE_RANGES }, allow_blank: true
  validates :latitude, presence: true, numericality: { in: -90..90 }
  validates :longitude, presence: true, numericality: { in: -180..180 }
  validate :acceptable_images

  # URL validation
  validate :valid_external_url
  validate :platform_matches_url

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_view_type, ->(type) { where(view_type: type) }
  scope :by_platform, ->(platform) { where(platform: platform) }
  scope :recent, -> { order(created_at: :desc) }
  scope :verified, -> { where.not(verified_at: nil) }
  scope :with_coordinates, -> { where.not(latitude: nil, longitude: nil) }
  scope :near_coordinates, ->(lat, lng, radius_km = 50) {
    where(
      "6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude))) < ?",
      lat, lng, lat, radius_km
    )
  }

  # Callbacks
  before_save :extract_platform_from_url, if: :external_url_changed?

  def verified?
    verified_at.present?
  end

  def platform_name
    case platform
    when 'airbnb' then 'Airbnb'
    when 'booking_com' then 'Booking.com'
    when 'vrbo' then 'VRBO'
    when 'hotels_com' then 'Hotels.com'
    when 'expedia' then 'Expedia'
    when 'kayak' then 'Kayak'
    else platform.titleize
    end
  end

  def view_type_display
    view_type.titleize
  end

  def short_description
    description.truncate(150)
  end

  def main_image
    images.attached? ? images.first : nil
  end

  def has_images?
    images.attached?
  end

  private

  def acceptable_images
    return unless images.attached?

    if images.count > 5
      errors.add(:images, 'You can upload a maximum of 5 images')
    end

    images.each do |image|
      unless image.content_type.in?(%w[image/jpeg image/jpg image/png image/webp])
        errors.add(:images, 'Images must be JPEG, PNG, or WebP format')
      end

      if image.byte_size > 10.megabytes
        errors.add(:images, 'Each image must be less than 10MB')
      end
    end
  end

  def valid_external_url
    return unless external_url.present?

    uri = URI.parse(external_url)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      errors.add(:external_url, 'must be a valid HTTP or HTTPS URL')
    end
  rescue URI::InvalidURIError
    errors.add(:external_url, 'must be a valid URL')
  end

  def platform_matches_url
    return unless external_url.present? && platform.present?

    domain = URI.parse(external_url).host&.downcase
    return unless domain

    expected_domains = {
      'airbnb' => ['airbnb.com', 'www.airbnb.com'],
      'booking_com' => ['booking.com', 'www.booking.com'],
      'vrbo' => ['vrbo.com', 'www.vrbo.com'],
      'hotels_com' => ['hotels.com', 'www.hotels.com'],
      'expedia' => ['expedia.com', 'www.expedia.com'],
      'kayak' => ['kayak.com', 'www.kayak.com']
    }

    if expected_domains[platform] && !expected_domains[platform].include?(domain)
      errors.add(:external_url, "must be from #{platform_name}")
    end
  end

  def extract_platform_from_url
    return unless external_url.present?

    domain = URI.parse(external_url).host&.downcase
    return unless domain

    detected_platform = case domain
                       when /airbnb\.com/
                         'airbnb'
                       when /booking\.com/
                         'booking_com'
                       when /vrbo\.com/
                         'vrbo'
                       when /hotels\.com/
                         'hotels_com'
                       when /expedia\.com/
                         'expedia'
                       when /kayak\.com/
                         'kayak'
                       end

    self.platform = detected_platform if detected_platform && platform.blank?
  rescue URI::InvalidURIError
    # URL validation will catch this
  end

  # Geographic helper methods
  def has_coordinates?
    latitude.present? && longitude.present?
  end

  def coordinates_display
    return "Location not set" unless has_coordinates?
    "#{latitude.round(4)}, #{longitude.round(4)}"
  end

  def distance_to(lat, lng)
    return nil unless has_coordinates?
    
    # Haversine formula for distance calculation
    earth_radius = 6371 # km
    
    lat1_rad = Math::PI * latitude / 180
    lat2_rad = Math::PI * lat / 180
    delta_lat_rad = Math::PI * (lat - latitude) / 180
    delta_lng_rad = Math::PI * (lng - longitude) / 180
    
    a = Math.sin(delta_lat_rad/2) * Math.sin(delta_lat_rad/2) +
        Math.cos(lat1_rad) * Math.cos(lat2_rad) *
        Math.sin(delta_lng_rad/2) * Math.sin(delta_lng_rad/2)
    
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    
    (earth_radius * c).round(2)
  end
end
