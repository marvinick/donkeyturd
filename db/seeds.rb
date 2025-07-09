# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
#
# Create a sample user if none exists
unless User.exists?
  user = User.create!(
    name: "John Doe",
    email: "john@example.com",
    password: "password123",
    password_confirmation: "password123"
  )

  # Create sample listings
  sample_listings = [
    {
      title: "Stunning Mountain View Cabin in Banff National Park",
      description: "Wake up to breathtaking views of the Canadian Rockies from this cozy cabin. Floor-to-ceiling windows offer panoramic mountain vistas, and the sunrise over the peaks is absolutely spectacular. Perfect for nature lovers seeking tranquility and Instagram-worthy moments.",
      external_url: "https://www.airbnb.com/rooms/12345678",
      platform: "airbnb",
      location: "Banff, Alberta, Canada",
      view_type: "mountain",
      price_range: "$201-$300",
      verified_at: Time.current
    },
    {
      title: "Oceanfront Villa with Private Beach Access",
      description: "Experience the ultimate coastal getaway with unobstructed ocean views from every room. Watch dolphins play in the waves while enjoying your morning coffee. The sound of crashing waves and endless blue horizon create the perfect peaceful retreat.",
      external_url: "https://www.vrbo.com/98765432",
      platform: "vrbo",
      location: "Malibu, California, USA",
      view_type: "ocean",
      price_range: "$500+",
      verified_at: Time.current
    },
    {
      title: "Sky-High Penthouse with Manhattan Skyline Views",
      description: "Perched on the 45th floor, this luxury penthouse offers 360-degree views of the Manhattan skyline. Watch the city lights twinkle at night and see the Empire State Building light up. The floor-to-ceiling windows make you feel like you're floating above the city.",
      external_url: "https://www.booking.com/hotel/us/manhattan-penthouse.html",
      platform: "booking_com",
      location: "New York City, New York, USA",
      view_type: "city",
      price_range: "$301-$500"
    },
    {
      title: "Lakeside Retreat with Pristine Water Views",
      description: "Nestled on the shores of a crystal-clear mountain lake, this charming cottage offers serene water views and perfect reflections of the surrounding forest. Ideal for watching sunsets paint the water gold and enjoying the peaceful sounds of nature.",
      external_url: "https://www.airbnb.com/rooms/11111111",
      platform: "airbnb",
      location: "Lake Tahoe, California, USA",
      view_type: "lake",
      price_range: "$101-$200",
      verified_at: Time.current
    },
    {
      title: "Desert Oasis with Spectacular Sunset Views",
      description: "Experience the magic of the desert with panoramic views of red rock formations and endless sky. The sunsets here are legendary, painting the entire landscape in brilliant oranges and purples. Perfect for stargazing with minimal light pollution.",
      external_url: "https://www.vrbo.com/33333333",
      platform: "vrbo",
      location: "Sedona, Arizona, USA",
      view_type: "desert",
      price_range: "$201-$300"
    },
    {
      title: "Forest Canopy Treehouse with Misty Valley Views",
      description: "Sleep among the treetops in this unique treehouse with sweeping views of the misty valley below. Wake up to the sounds of birds chirping and watch fog roll through the ancient forest. A truly magical experience surrounded by nature.",
      external_url: "https://www.airbnb.com/rooms/44444444",
      platform: "airbnb",
      location: "Olympic National Park, Washington, USA",
      view_type: "forest",
      price_range: "$101-$200",
      verified_at: Time.current
    }
  ]

  sample_listings.each do |listing_data|
    user.listings.create!(listing_data)
  end

  puts "Created #{sample_listings.count} sample listings!"
end
