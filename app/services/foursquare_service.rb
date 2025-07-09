# Foursquare API integration service
class FoursquareService < ApiIntegrationService
  BASE_URL = 'https://api.foursquare.com/v3/places'
  
  def initialize(api_key:)
    super(api_key: api_key)
  end
  
  def search_locations(query, limit: 10)
    params = {
      query: query,
      categories: '16000', # Arts & Entertainment
      limit: limit
    }
    
    response = make_request("#{BASE_URL}/search", params)
    
    response.dig('results')&.map do |place|
      {
        external_id: place['fsq_id'],
        name: place['name'],
        description: place.dig('location', 'formatted_address'),
        address: place.dig('location', 'formatted_address'),
        rating: place['rating'],
        source: 'foursquare'
      }
    end || []
  rescue => e
    Rails.logger.error "Foursquare search error: #{e.message}"
    []
  end
  
  def fetch_location_details(external_id)
    response = make_request("#{BASE_URL}/#{external_id}")
    
    {
      external_id: response['fsq_id'],
      name: response['name'],
      description: response['description'] || response.dig('location', 'formatted_address'),
      address: response.dig('location', 'formatted_address'),
      latitude: response.dig('geocodes', 'main', 'latitude'),
      longitude: response.dig('geocodes', 'main', 'longitude'),
      rating: response['rating'],
      phone: response['tel'],
      website: response['website'],
      photos: extract_photos(response),
      source: 'foursquare',
      raw_data: response
    }
  rescue => e
    Rails.logger.error "Foursquare details error: #{e.message}"
    nil
  end
  
  def import_to_listing(external_id, user)
    details = fetch_location_details(external_id)
    return nil unless details
    
    # Check if already imported
    existing = Listing.find_by(external_source: 'foursquare', external_id: external_id)
    return existing if existing
    
    listing = Listing.new(
      user: user,
      name: details[:name],
      description: details[:description],
      address: details[:address],
      latitude: details[:latitude],
      longitude: details[:longitude],
      phone_number: details[:phone],
      booking_url: details[:website],
      external_id: external_id,
      external_source: 'foursquare',
      external_data: details[:raw_data].to_json,
      import_status: 'imported'
    )
    
    if listing.save
      # Queue background job to import photos
      ImportPhotosJob.perform_later(listing.id, details[:photos]) if details[:photos].present?
      listing
    else
      Rails.logger.error "Failed to import Foursquare listing: #{listing.errors.full_messages}"
      nil
    end
  end
  
  protected
  
  def add_headers(request)
    super
    request['Authorization'] = api_key
    request['Accept'] = 'application/json'
  end
  
  private
  
  def extract_photos(response)
    # Foursquare photos require separate API call
    return [] unless response['fsq_id']
    
    begin
      photos_response = make_request("#{BASE_URL}/#{response['fsq_id']}/photos")
      photos_response&.map { |photo| photo['prefix'] + 'original' + photo['suffix'] } || []
    rescue
      []
    end
  end
end
