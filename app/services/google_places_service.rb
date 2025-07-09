# Google Places API integration service
class GooglePlacesService < ApiIntegrationService
  BASE_URL = 'https://maps.googleapis.com/maps/api/place'
  
  def initialize(api_key:)
    super(api_key: api_key)
  end
  
  def search_locations(query, limit: 10)
    params = {
      key: api_key,
      query: query,
      type: 'tourist_attraction'
    }
    
    response = make_request("#{BASE_URL}/textsearch/json", params)
    
    response.dig('results')&.first(limit)&.map do |place|
      {
        external_id: place['place_id'],
        name: place['name'],
        description: place['formatted_address'],
        address: place['formatted_address'],
        rating: place['rating'],
        source: 'google_places'
      }
    end || []
  rescue => e
    Rails.logger.error "Google Places search error: #{e.message}"
    []
  end
  
  def fetch_location_details(external_id)
    params = {
      key: api_key,
      place_id: external_id,
      fields: 'place_id,name,formatted_address,geometry,rating,formatted_phone_number,website,photos,reviews'
    }
    
    response = make_request("#{BASE_URL}/details/json", params)
    result = response['result']
    
    {
      external_id: result['place_id'],
      name: result['name'],
      description: extract_description(result),
      address: result['formatted_address'],
      latitude: result.dig('geometry', 'location', 'lat'),
      longitude: result.dig('geometry', 'location', 'lng'),
      rating: result['rating'],
      phone: result['formatted_phone_number'],
      website: result['website'],
      photos: extract_photos(result),
      source: 'google_places',
      raw_data: result
    }
  rescue => e
    Rails.logger.error "Google Places details error: #{e.message}"
    nil
  end
  
  def import_to_listing(external_id, user)
    details = fetch_location_details(external_id)
    return nil unless details
    
    # Check if already imported
    existing = Listing.find_by(external_source: 'google_places', external_id: external_id)
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
      platform: 'other',
      view_type: 'other', # Will need to be set manually or inferred
      external_id: external_id,
      external_source: 'google_places',
      external_data: details[:raw_data].to_json,
      import_status: 'imported'
    )
    
    if listing.save
      # Queue background job to import photos
      ImportPhotosJob.perform_later(listing.id, details[:photos]) if details[:photos].present?
      listing
    else
      Rails.logger.error "Failed to import Google Places listing: #{listing.errors.full_messages}"
      nil
    end
  end
  
  protected
  
  def add_headers(request)
    super
    request['Accept'] = 'application/json'
  end
  
  private
  
  def extract_description(result)
    # Use first review as description if available
    first_review = result.dig('reviews', 0, 'text')
    return first_review if first_review.present?
    
    # Fallback to formatted address
    result['formatted_address']
  end
  
  def extract_photos(result)
    return [] unless result['photos']
    
    result['photos'].map do |photo|
      # Google Photos API requires additional call, store photo reference for background job
      {
        photo_reference: photo['photo_reference'],
        width: photo['width'],
        height: photo['height']
      }
    end
  end
end
