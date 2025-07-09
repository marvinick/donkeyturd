class TripAdvisorImportJob < ApplicationJob
  queue_as :default
  
  def perform(location_query, user_id, import_options = {})
    user = User.find(user_id)
    service = TripAdvisorService.new
    
    begin
      # Search for locations
      search_results = service.search_locations(location_query, category: 'hotels')
      
      return if search_results['data'].blank?
      
      imported_count = 0
      
      search_results['data'].each do |location_data|
        next unless should_import_location?(location_data, import_options)
        
        begin
          listing = create_listing_from_tripadvisor(location_data, user, service)
          imported_count += 1 if listing&.persisted?
        rescue => e
          Rails.logger.error "Failed to import location #{location_data['location_id']}: #{e.message}"
          next
        end
        
        # Rate limiting - be respectful to the API
        sleep(0.5)
        
        # Stop if we've imported enough
        break if imported_count >= (import_options[:limit] || 10)
      end
      
      Rails.logger.info "TripAdvisor import completed: #{imported_count} listings imported"
      
    rescue => e
      Rails.logger.error "TripAdvisor import failed: #{e.message}"
      raise e
    end
  end
  
  private
  
  def should_import_location?(location_data, options)
    # Skip if we already have this location
    return false if Listing.exists?(tripadvisor_location_id: location_data['location_id'])
    
    # Check if it has view-related keywords
    name = location_data['name']&.downcase || ''
    description = location_data['description']&.downcase || ''
    
    view_keywords = ['view', 'scenic', 'mountain', 'ocean', 'lake', 'city', 'river', 'valley', 'forest', 'beach', 'panoramic']
    
    has_view_keywords = view_keywords.any? { |keyword| name.include?(keyword) || description.include?(keyword) }
    
    # Must have decent rating (3+ stars)
    rating = location_data['rating']&.to_f || 0
    has_good_rating = rating >= 3.0
    
    # Must have some photos
    has_photos = location_data['photo']&.present?
    
    has_view_keywords && has_good_rating && has_photos
  end
  
  def create_listing_from_tripadvisor(location_data, user, service)
    # Get detailed information
    details = service.get_location_details(location_data['location_id'])
    
    # Extract basic info
    name = location_data['name']
    description = extract_description(details)
    location_string = extract_location(location_data, details)
    view_type = detect_view_type(name, description)
    price_range = extract_price_range(details)
    
    # Create the listing
    listing = user.listings.build(
      title: name,
      description: description,
      location: location_string,
      view_type: view_type,
      price_range: price_range,
      platform: 'other', # TripAdvisor doesn't directly book
      external_url: location_data['web_url'],
      tripadvisor_location_id: location_data['location_id'],
      tripadvisor_rating: location_data['rating']&.to_f,
      verified_at: Time.current, # Auto-verify TripAdvisor imports
      admin_notes: "Imported from TripAdvisor on #{Date.current}"
    )
    
    if listing.save
      # Import photos in background
      ImportTripAdvisorPhotosJob.perform_later(listing.id, location_data['location_id'])
      listing
    else
      Rails.logger.error "Failed to save TripAdvisor listing: #{listing.errors.full_messages.join(', ')}"
      nil
    end
  end
  
  def extract_description(details)
    description = details['description'] || details['web_url'] || ''
    
    # If description is too short, create one
    if description.length < 50
      location_name = details['name'] || 'this location'
      address = details['address_obj']&.dig('address_string') || 'a beautiful destination'
      description = "Experience stunning views at #{location_name} located in #{address}. This carefully selected accommodation offers exceptional scenery and memorable experiences for travelers seeking beautiful vistas."
    end
    
    # Ensure it meets our minimum length requirement
    description.truncate(1000)
  end
  
  def extract_location(location_data, details)
    if details['address_obj']
      address = details['address_obj']
      parts = [
        address['street1'],
        address['city'],
        address['state'],
        address['country']
      ].compact.select(&:present?)
      
      parts.join(', ')
    else
      location_data['location_string'] || 'Location details not available'
    end
  end
  
  def detect_view_type(name, description)
    text = "#{name} #{description}".downcase
    
    view_mappings = {
      'mountain' => ['mountain', 'peak', 'summit', 'alpine', 'highland'],
      'ocean' => ['ocean', 'sea', 'seaside', 'coastal', 'waterfront'],
      'lake' => ['lake', 'lakeside', 'lakefront'],
      'city' => ['city', 'urban', 'skyline', 'downtown', 'metropolitan'],
      'river' => ['river', 'riverside', 'waterway'],
      'forest' => ['forest', 'woods', 'woodland', 'trees'],
      'beach' => ['beach', 'shore', 'sand'],
      'valley' => ['valley', 'gorge'],
      'canyon' => ['canyon', 'cliff']
    }
    
    view_mappings.each do |view_type, keywords|
      return view_type if keywords.any? { |keyword| text.include?(keyword) }
    end
    
    # Default to city view if no specific type detected
    'city'
  end
  
  def extract_price_range(details)
    # TripAdvisor API might have price_level or price information
    price_level = details['price_level'] || details['price']
    
    case price_level
    when '$', '1'
      '$0-$50'
    when '$$', '2'
      '$51-$100'
    when '$$$', '3'
      '$101-$200'
    when '$$$$', '4'
      '$201-$300'
    when '$$$$$', '5'
      '$301-$500'
    else
      nil # Leave blank if unknown
    end
  end
end
