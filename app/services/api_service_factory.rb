# Factory for creating API service instances
class ApiServiceFactory
  SERVICES = {
    'tripadvisor' => TripadvisorService,
    'google_places' => GooglePlacesService,
    'foursquare' => FoursquareService
  }.freeze
  
  def self.available_sources
    SERVICES.keys
  end
  
  def self.create(source, api_key:)
    service_class = SERVICES[source.to_s]
    raise ArgumentError, "Unknown API source: #{source}" unless service_class
    
    service_class.new(api_key: api_key)
  end
  
  def self.search_all_sources(query, limit: 5)
    results = {}
    
    SERVICES.each do |source, service_class|
      begin
        api_key = api_key_for(source)
        next unless api_key.present?
        
        service = service_class.new(api_key: api_key)
        results[source] = service.search_locations(query, limit: limit)
      rescue => e
        Rails.logger.error "Error searching #{source}: #{e.message}"
        results[source] = []
      end
    end
    
    results
  end
  
  private
  
  def self.api_key_for(source)
    case source
    when 'tripadvisor'
      Rails.application.credentials.tripadvisor&.api_key
    when 'google_places'
      Rails.application.credentials.google&.places_api_key
    when 'foursquare'
      Rails.application.credentials.foursquare&.api_key
    end
  end
end
