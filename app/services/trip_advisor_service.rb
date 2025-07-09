class TripAdvisorService
  include HTTParty
  base_uri 'https://api.content.tripadvisor.com/api/v1'
  
  def initialize
    @api_key = Rails.application.credentials.tripadvisor_api_key || ENV['TRIPADVISOR_API_KEY']
    raise 'TripAdvisor API key not found' unless @api_key
    
    self.class.default_params(key: @api_key)
  end
  
  # Search for locations by name
  def search_locations(query, category: 'hotels', limit: 20)
    options = {
      query: {
        searchQuery: query,
        category: category,
        language: 'en'
      }
    }
    
    response = self.class.get('/location/search', options)
    handle_response(response)
  end
  
  # Get location details by location_id
  def get_location_details(location_id)
    options = {
      query: {
        language: 'en',
        currency: 'USD'
      }
    }
    
    response = self.class.get("/location/#{location_id}/details", options)
    handle_response(response)
  end
  
  # Get photos for a location
  def get_location_photos(location_id, limit: 5)
    options = {
      query: {
        language: 'en',
        limit: limit
      }
    }
    
    response = self.class.get("/location/#{location_id}/photos", options)
    handle_response(response)
  end
  
  # Get reviews for a location
  def get_location_reviews(location_id, limit: 10)
    options = {
      query: {
        language: 'en',
        limit: limit
      }
    }
    
    response = self.class.get("/location/#{location_id}/reviews", options)
    handle_response(response)
  end
  
  # Search for hotels with scenic views
  def search_scenic_hotels(location, view_types: ['mountain', 'ocean', 'lake', 'city'])
    search_terms = view_types.map { |type| "#{type} view" }.join(' OR ')
    query = "#{location} hotel #{search_terms}"
    
    search_locations(query, category: 'hotels')
  end
  
  private
  
  def handle_response(response)
    case response.code
    when 200
      response.parsed_response
    when 401
      raise 'Invalid API key or unauthorized access'
    when 429
      raise 'Rate limit exceeded'
    when 500..599
      raise 'TripAdvisor API server error'
    else
      raise "API request failed with code #{response.code}: #{response.body}"
    end
  rescue => e
    Rails.logger.error "TripAdvisor API Error: #{e.message}"
    raise e
  end
end
