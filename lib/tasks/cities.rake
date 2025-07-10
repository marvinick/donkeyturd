namespace :cities do
  desc "Seed cities data from existing listings"
  task :seed_from_listings => :environment do
    puts "Analyzing existing listings to create city data..."
    
    locations = Listing.distinct.pluck(:location).compact
    created_count = 0
    
    locations.each do |location|
      # Skip if city already exists
      next if find_existing_city(location)
      
      # Try to create city from location string
      city_data = parse_location(location)
      next unless city_data
      
      # Create city
      city = City.create!(city_data)
      
      # Update listings to reference this city
      update_listings_for_city(city, location)
      
      created_count += 1
      puts "Created city: #{city.display_name} (#{city.listings_count} listings)"
    end
    
    puts "Seed complete. Created #{created_count} new cities."
    update_all_city_listing_counts
  end
  
  desc "Update listing counts for all cities"
  task :update_counts => :environment do
    puts "Updating listing counts for all cities..."
    update_all_city_listing_counts
    puts "Listing counts updated."
  end
  
  desc "Auto-assign cities to listings without city_id"
  task :auto_assign => :environment do
    puts "Auto-assigning cities to listings..."
    
    Listing.where(city_id: nil).find_each do |listing|
      city = find_best_city_match(listing)
      if city
        listing.update!(city: city)
        puts "Assigned #{listing.title} to #{city.display_name}"
      end
    end
    
    update_all_city_listing_counts
    puts "Auto-assignment complete."
  end
  
  desc "Generate programmatic content for all cities"
  task :generate_content => :environment do
    puts "Generating programmatic content for cities..."
    
    City.with_listings.find_each do |city|
      puts "Processing #{city.display_name}..."
      
      # Generate view type content
      city.listings_by_view_type.each do |view_type, count|
        next if count.zero?
        content = city.generate_view_type_content(view_type)
        puts "  - #{content[:title]} (#{content[:count]} properties)"
      end
      
      # Generate destination guide
      guide = city.generate_destination_guide
      puts "  - Generated destination guide with #{guide[:view_types_overview].size} view types"
    end
    
    puts "Content generation complete."
  end
  
  desc "Auto-assign cities to existing listings based on coordinates"
  task assign_to_listings: :environment do
    puts "Starting city assignment for existing listings..."
    
    listings_without_city = Listing.where(city_id: nil).with_coordinates
    total_count = listings_without_city.count
    
    puts "Found #{total_count} listings without assigned cities"
    
    if total_count == 0
      puts "No listings need city assignment"
      next
    end
    
    updated_count = 0
    
    listings_without_city.find_each.with_index do |listing, index|
      nearest_city = listing.find_nearest_city
      
      if nearest_city
        listing.update_column(:city_id, nearest_city.id)
        updated_count += 1
        puts "#{index + 1}/#{total_count}: Assigned #{listing.title} to #{nearest_city.display_name}"
      else
        puts "#{index + 1}/#{total_count}: No nearby city found for #{listing.title}"
      end
      
      # Progress update every 10 listings
      if (index + 1) % 10 == 0
        puts "Progress: #{index + 1}/#{total_count} listings processed"
      end
    end
    
    puts "\nCity assignment completed!"
    puts "Updated #{updated_count} out of #{total_count} listings"
    
    # Update city listing counts
    puts "\nUpdating city listing counts..."
    City.find_each do |city|
      count = city.listings.active.count
      city.update_column(:listings_count, count)
      puts "#{city.display_name}: #{count} listings" if count > 0
    end
    
    puts "\nCity listing counts updated!"
  end
  
  desc "Show city assignment statistics"
  task stats: :environment do
    puts "City Assignment Statistics"
    puts "=" * 40
    
    total_listings = Listing.count
    assigned_listings = Listing.where.not(city_id: nil).count
    unassigned_listings = total_listings - assigned_listings
    
    puts "Total listings: #{total_listings}"
    puts "Assigned to cities: #{assigned_listings}"
    puts "Unassigned: #{unassigned_listings}"
    puts "Assignment rate: #{((assigned_listings.to_f / total_listings) * 100).round(1)}%"
    
    puts "\nCities with listings:"
    City.with_listings.by_listings_count.each do |city|
      puts "  #{city.display_name}: #{city.listings_count} listings"
    end
    
    puts "\nListings by view type:"
    Listing::VIEW_TYPES.each do |view_type|
      count = Listing.where(view_type: view_type).count
      puts "  #{view_type.humanize}: #{count} listings"
    end
  end
  
  private
  
  def find_existing_city(location)
    # Try exact match first
    City.where("LOWER(name) = ? OR LOWER(slug) = ?", 
               location.downcase, 
               location.downcase.gsub(/[^a-z0-9\s-]/, '').gsub(/\s+/, '-')).first
  end
  
  def parse_location(location)
    # Basic parsing - you might want to integrate with geocoding API for better results
    parts = location.split(',').map(&:strip)
    return nil if parts.empty?
    
    name = parts.first
    state_province = parts.size > 1 ? parts[-2] : nil
    country = parts.size > 1 ? parts.last : "Unknown"
    
    # Basic coordinates (you'd want to use a geocoding service here)
    lat, lng = get_coordinates_for_location(location)
    
    {
      name: name,
      state_province: state_province,
      country: country,
      latitude: lat || 0.0,
      longitude: lng || 0.0,
      featured: false,
      listings_count: 0
    }
  rescue => e
    puts "Error parsing location '#{location}': #{e.message}"
    nil
  end
  
  def get_coordinates_for_location(location)
    # Placeholder - integrate with geocoding service like Google Maps or OpenStreetMap
    # For now, return default coordinates
    [40.7128, -74.0060] # NYC coordinates as default
  end
  
  def update_listings_for_city(city, location)
    Listing.where(location: location).update_all(city_id: city.id)
    city.update!(listings_count: city.listings.active.count)
  end
  
  def find_best_city_match(listing)
    return nil unless listing.location.present?
    
    # Try to find existing city that matches
    location_parts = listing.location.split(',').map(&:strip)
    
    location_parts.each do |part|
      city = City.where("LOWER(name) LIKE ?", "%#{part.downcase}%").first
      return city if city
    end
    
    # If coordinates exist, find nearest city
    if listing.latitude.present? && listing.longitude.present?
      return City.near_coordinates(listing.latitude, listing.longitude, 50).first
    end
    
    nil
  end
  
  def update_all_city_listing_counts
    City.find_each do |city|
      count = city.listings.active.count
      city.update!(listings_count: count) if city.listings_count != count
    end
  end
end
