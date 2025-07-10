class SeedCitiesData < ActiveRecord::Migration[8.0]
  def up
    # Popular tourist destinations with scenic accommodations
    cities_data = [
      # North America
      { name: "Banff", state_province: "Alberta", country: "Canada", latitude: 51.1784, longitude: -115.5708, featured: true, description: "Nestled in the heart of the Canadian Rockies" },
      { name: "Aspen", state_province: "Colorado", country: "USA", latitude: 39.1911, longitude: -106.8175, featured: true, description: "World-renowned ski resort with mountain views" },
      { name: "Big Sur", state_province: "California", country: "USA", latitude: 36.2704, longitude: -121.8081, featured: true, description: "Dramatic coastline with ocean and forest views" },
      { name: "Sedona", state_province: "Arizona", country: "USA", latitude: 34.8697, longitude: -111.7610, featured: false, description: "Red rock formations and desert landscapes" },
      { name: "Napa Valley", state_province: "California", country: "USA", latitude: 38.5025, longitude: -122.2654, featured: false, description: "Rolling hills and vineyard views" },
      { name: "Key West", state_province: "Florida", country: "USA", latitude: 24.5551, longitude: -81.7800, featured: false, description: "Tropical paradise with ocean views" },
      { name: "Charleston", state_province: "South Carolina", country: "USA", latitude: 32.7765, longitude: -79.9311, featured: false, description: "Historic charm with harbor views" },
      { name: "Vancouver", state_province: "British Columbia", country: "Canada", latitude: 49.2827, longitude: -123.1207, featured: false, description: "Mountains meet ocean in this coastal city" },
      
      # Europe
      { name: "Santorini", state_province: "", country: "Greece", latitude: 36.3932, longitude: 25.4615, featured: true, description: "Iconic whitewashed buildings with ocean views" },
      { name: "Zermatt", state_province: "", country: "Switzerland", latitude: 45.9763, longitude: 7.6586, featured: true, description: "Alpine village below the Matterhorn" },
      { name: "Positano", state_province: "", country: "Italy", latitude: 40.6280, longitude: 14.4850, featured: true, description: "Cliffside town on the Amalfi Coast" },
      { name: "Hallstatt", state_province: "", country: "Austria", latitude: 47.5622, longitude: 13.6493, featured: false, description: "Lakeside village in the Alps" },
      { name: "Lauterbrunnen", state_province: "", country: "Switzerland", latitude: 46.5931, longitude: 7.9073, featured: false, description: "Valley of waterfalls surrounded by mountains" },
      { name: "Cinque Terre", state_province: "", country: "Italy", latitude: 44.1009, longitude: 9.7226, featured: false, description: "Coastal villages with Mediterranean views" },
      { name: "Reykjavik", state_province: "", country: "Iceland", latitude: 64.1466, longitude: -21.9426, featured: false, description: "Northern lights and dramatic landscapes" },
      { name: "Porto", state_province: "", country: "Portugal", latitude: 41.1579, longitude: -8.6291, featured: false, description: "Historic city with river and ocean views" },
      
      # Asia Pacific
      { name: "Bali", state_province: "", country: "Indonesia", latitude: -8.3405, longitude: 115.0920, featured: true, description: "Tropical paradise with rice terraces and beaches" },
      { name: "Kyoto", state_province: "", country: "Japan", latitude: 35.0116, longitude: 135.7681, featured: false, description: "Ancient temples with mountain and garden views" },
      { name: "Queenstown", state_province: "", country: "New Zealand", latitude: -45.0312, longitude: 168.6626, featured: true, description: "Adventure capital with lake and mountain views" },
      { name: "Milford Sound", state_province: "", country: "New Zealand", latitude: -44.6667, longitude: 167.9167, featured: false, description: "Fjord with waterfalls and mountain peaks" },
      { name: "Phi Phi Islands", state_province: "", country: "Thailand", latitude: 7.7367, longitude: 98.7784, featured: false, description: "Tropical islands with crystal clear waters" },
      { name: "Jiuzhaigou", state_province: "", country: "China", latitude: 33.2197, longitude: 103.9197, featured: false, description: "Colorful lakes and mountain scenery" },
      
      # South America
      { name: "Machu Picchu", state_province: "", country: "Peru", latitude: -13.1631, longitude: -72.5450, featured: true, description: "Ancient citadel with mountain views" },
      { name: "Patagonia", state_province: "", country: "Chile", latitude: -50.9423, longitude: -73.4068, featured: false, description: "Dramatic landscapes with glaciers and peaks" },
      { name: "Rio de Janeiro", state_province: "", country: "Brazil", latitude: -22.9068, longitude: -43.1729, featured: false, description: "Iconic beaches with mountain backdrops" },
      { name: "Ushuaia", state_province: "", country: "Argentina", latitude: -54.8019, longitude: -68.3030, featured: false, description: "End of the world with mountain and sea views" },
      
      # Africa
      { name: "Cape Town", state_province: "", country: "South Africa", latitude: -33.9249, longitude: 18.4241, featured: false, description: "Table Mountain meets ocean views" },
      { name: "Serengeti", state_province: "", country: "Tanzania", latitude: -2.3333, longitude: 34.8333, featured: false, description: "Endless plains with wildlife views" },
      { name: "Victoria Falls", state_province: "", country: "Zambia", latitude: -17.9243, longitude: 25.8572, featured: false, description: "One of the world's largest waterfalls" },
      
      # Oceania
      { name: "Great Barrier Reef", state_province: "Queensland", country: "Australia", latitude: -18.2871, longitude: 147.6992, featured: false, description: "World's largest coral reef system" },
      { name: "Blue Mountains", state_province: "New South Wales", country: "Australia", latitude: -33.7022, longitude: 150.3111, featured: false, description: "Dramatic cliffs and eucalyptus forests" },
      { name: "Bora Bora", state_province: "", country: "French Polynesia", latitude: -16.5004, longitude: -151.7415, featured: false, description: "Lagoon with coral and volcanic peaks" }
    ]
    
    cities_data.each do |city_attrs|
      city = City.find_or_create_by(name: city_attrs[:name], country: city_attrs[:country]) do |c|
        c.state_province = city_attrs[:state_province]
        c.latitude = city_attrs[:latitude]
        c.longitude = city_attrs[:longitude]
        c.featured = city_attrs[:featured]
        c.description = city_attrs[:description]
        c.listings_count = 0
      end
      
      puts "Created/Updated city: #{city.display_name}"
    end
    
    puts "Seeded #{cities_data.count} cities"
  end

  def down
    # Only remove cities that have no listings
    City.where(listings_count: 0).destroy_all
  end
end
