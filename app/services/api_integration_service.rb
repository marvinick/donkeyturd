# Base class for all external API integrations
class ApiIntegrationService
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :api_key, :string
  attribute :timeout, :integer, default: 30
  
  # Abstract methods - must be implemented by subclasses
  def search_locations(query, limit: 10)
    raise NotImplementedError, "Subclass must implement #search_locations"
  end
  
  def fetch_location_details(external_id)
    raise NotImplementedError, "Subclass must implement #fetch_location_details"
  end
  
  def import_to_listing(external_id, user)
    raise NotImplementedError, "Subclass must implement #import_to_listing"
  end
  
  # Common utility methods
  protected
  
  def make_request(url, params = {})
    uri = URI(url)
    uri.query = URI.encode_www_form(params) if params.any?
    
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', 
                               read_timeout: timeout, open_timeout: timeout) do |http|
      request = Net::HTTP::Get.new(uri)
      add_headers(request)
      http.request(request)
    end
    
    handle_response(response)
  end
  
  def add_headers(request)
    request['User-Agent'] = 'ViewsApp/1.0'
    request['Accept'] = 'application/json'
  end
  
  def handle_response(response)
    case response.code.to_i
    when 200..299
      JSON.parse(response.body)
    when 401
      raise ApiError, "Unauthorized: Check your API key"
    when 429
      raise ApiError, "Rate limit exceeded"
    when 500..599
      raise ApiError, "Server error: #{response.code}"
    else
      raise ApiError, "API request failed: #{response.code} - #{response.body}"
    end
  rescue JSON::ParserError
    raise ApiError, "Invalid JSON response"
  end
  
  def normalize_view_type(raw_category)
    # Map external API categories to our view types
    category_mappings = {
      'beach' => 'beach',
      'mountain' => 'mountain', 
      'lake' => 'lake',
      'ocean' => 'ocean',
      'city' => 'city',
      'nature' => 'forest',
      'desert' => 'desert',
      'river' => 'river',
      'canyon' => 'canyon',
      'valley' => 'valley'
    }
    
    normalized = raw_category.to_s.downcase
    category_mappings[normalized] || 'other'
  end
  
  def extract_price_range(price_data)
    # Extract and normalize price information
    return nil unless price_data
    
    if price_data.is_a?(Hash)
      min_price = price_data['min'] || price_data['minimum'] || 0
      max_price = price_data['max'] || price_data['maximum'] || min_price
      avg_price = (min_price + max_price) / 2
    else
      avg_price = price_data.to_f
    end
    
    case avg_price
    when 0..50 then '$0-$50'
    when 51..100 then '$51-$100'
    when 101..200 then '$101-$200'
    when 201..300 then '$201-$300'
    when 301..500 then '$301-$500'
    else '$500+'
    end
  end

  class ApiError < StandardError; end
end
