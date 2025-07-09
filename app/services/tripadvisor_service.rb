# TripAdvisor API integration service
class TripadvisorService < ApiIntegrationService
  BASE_URL = 'https://api.content.tripadvisor.com/api/v1'
  
  def initialize(api_key:)
    super(api_key: api_key)
  end
  
  def search_locations(query, limit: 10)
    params = {
      key: api_key,
      searchQuery: query,
      category: 'attractions',
      language: 'en'
    }
    
    response = make_request("#{BASE_URL}/location/search", params)
    
    response.dig('data')&.first(limit)&.map do |location|
      {
        external_id: location['location_id'],
        name: location['name'],
        description: location['description'],
        address: location['address_obj']&.dig('address_string'),
        rating: location['rating'],
        source: 'tripadvisor'
      }
    end || []
  rescue => e
    Rails.logger.error "TripAdvisor search error: #{e.message}"
    []
  end
  
  def fetch_location_details(external_id)
    params = {
      key: api_key,
      language: 'en'
    }
    
    response = make_request("#{BASE_URL}/location/#{external_id}/details", params)
    
    {
      external_id: response['location_id'],
      name: response['name'],
      description: response['description'],
      address: response['address_obj']&.dig('address_string'),
      latitude: response['latitude'],
      longitude: response['longitude'],
      rating: response['rating'],
      phone: response['phone'],
      website: response['website'],
      photos: extract_photos(response),
      source: 'tripadvisor',
      raw_data: response
    }
  rescue => e
    Rails.logger.error "TripAdvisor details error: #{e.message}"
    nil
  end
  
  def import_to_listing(external_id, user)
    details = fetch_location_details(external_id)
    return nil unless details
    
    # Check if already imported
    existing = Listing.find_by(external_source: 'tripadvisor', external_id: external_id)
    return existing if existing
    
    listing = Listing.new(
      user: user,
      title: details[:name],
      description: details[:description],
      location: details[:address],
      latitude: details[:latitude],
      longitude: details[:longitude],
      phone_number: details[:phone],
      external_url: details[:website],
      platform: 'other', # TripAdvisor isn't a booking platform directly
      view_type: 'other', # Will need to be set manually or inferred
      external_id: external_id,
      external_source: 'tripadvisor',
      external_data: details[:raw_data].to_json,
      import_status: 'imported'
    )
    
    if listing.save
      # Queue background job to import photos
      ImportPhotosJob.perform_later(listing.id, details[:photos]) if details[:photos].present?
      listing
    else
      Rails.logger.error "Failed to import TripAdvisor listing: #{listing.errors.full_messages}"
      nil
    end
  end
  
  protected
  
  def add_headers(request)
    super
    request['Accept'] = 'application/json'
  end
  
  private
  
  def extract_photos(response)
    response.dig('photos')&.map do |photo|
      photo.dig('images', 'large', 'url') || photo.dig('images', 'medium', 'url')
    end&.compact || []
  end
end
