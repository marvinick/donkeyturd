require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper
  
  self.use_transactional_tests = false
  fixtures :none  # Disable fixtures

  def setup
    # Don't use fixtures, create fresh test data
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
    
    @city = City.create!(
      name: 'Test City',
      slug: 'test-city',
      country: 'USA',
      state_province: 'CA',
      latitude: 40.7128,
      longitude: -74.0060,
      description: 'A test city'
    )
    
    # Create a user-created listing
    @user_listing = Listing.create!(
      title: "Beautiful Mountain View Cabin",
      description: "A cozy cabin with stunning mountain views perfect for a weekend getaway",
      location: "Aspen, Colorado",
      view_type: "mountain",
      platform: "airbnb",
      external_url: "https://airbnb.com/rooms/12345",
      price_range: "$201-$300",
      latitude: 39.1911,
      longitude: -106.8175,
      verified_at: Time.current,
      city: @city,
      user: @user
    )
    
    # Create an API-imported listing (TripAdvisor)
    @api_listing = Listing.create!(
      title: "Scenic Lake Resort - Imported from TripAdvisor",
      description: "Beautiful lakeside resort with panoramic views, imported from TripAdvisor for verification",
      location: "Lake Tahoe, California",
      view_type: "lake",
      platform: "other",
      external_url: "https://tripadvisor.com/hotel/12345",
      price_range: "$301-$500",
      latitude: 39.0968,
      longitude: -120.0324,
      verified_at: Time.current,
      city: @city,
      user: @user,
      external_source: "tripadvisor",
      external_id: "ta_12345",
      external_data: {
        tripadvisor_id: "12345",
        rating: 4.5,
        review_count: 120,
        original_data: { source: "tripadvisor" }
      }.to_json,
      import_status: "imported"
    )
  end

  def teardown
    # Clean up test data
    Listing.destroy_all
    City.destroy_all
    User.destroy_all
  end

  test "listing_schema works for user-created listings" do
    schema = listing_schema(@user_listing)
    
    assert_equal "LodgingBusiness", schema[:@type]
    assert_equal @user_listing.title, schema[:name]
    assert_equal strip_tags(@user_listing.description), schema[:description]
    assert_equal listing_url(@user_listing), schema[:url]
    assert_equal @user_listing.external_url, schema[:sameAs]
    assert_equal @user_listing.price_range, schema[:priceRange]
    
    # Check address
    assert_equal "PostalAddress", schema[:address][:@type]
    assert_equal @user_listing.location, schema[:address][:addressLocality]
    assert_equal @user_listing.city.name, schema[:address][:addressRegion]
    
    # Check coordinates
    assert_equal "GeoCoordinates", schema[:geo][:@type]
    assert_equal @user_listing.latitude, schema[:geo][:latitude]
    assert_equal @user_listing.longitude, schema[:geo][:longitude]
    
    # Check amenities
    assert_equal "LocationFeatureSpecification", schema[:amenityFeature][0][:@type]
    assert_equal "#{@user_listing.view_type_display} View", schema[:amenityFeature][0][:name]
    assert_equal true, schema[:amenityFeature][0][:value]
    
    # Check verification
    assert_equal "EducationalOccupationalCredential", schema[:hasCredential][:@type]
    assert_equal "Verified Listing", schema[:hasCredential][:name]
  end

  test "listing_schema works for API-imported listings" do
    schema = listing_schema(@api_listing)
    
    assert_equal "LodgingBusiness", schema[:@type]
    assert_equal @api_listing.title, schema[:name]
    assert_equal strip_tags(@api_listing.description), schema[:description]
    assert_equal listing_url(@api_listing), schema[:url]
    assert_equal @api_listing.external_url, schema[:sameAs]
    assert_equal @api_listing.price_range, schema[:priceRange]
    
    # Check address
    assert_equal "PostalAddress", schema[:address][:@type]
    assert_equal @api_listing.location, schema[:address][:addressLocality]
    assert_equal @api_listing.city.name, schema[:address][:addressRegion]
    
    # Check coordinates
    assert_equal "GeoCoordinates", schema[:geo][:@type]
    assert_equal @api_listing.latitude, schema[:geo][:latitude]
    assert_equal @api_listing.longitude, schema[:geo][:longitude]
    
    # Check amenities
    assert_equal "LocationFeatureSpecification", schema[:amenityFeature][0][:@type]
    assert_equal "#{@api_listing.view_type_display} View", schema[:amenityFeature][0][:name]
    assert_equal true, schema[:amenityFeature][0][:value]
    
    # Check verification
    assert_equal "EducationalOccupationalCredential", schema[:hasCredential][:@type]
    assert_equal "Verified Listing", schema[:hasCredential][:name]
  end

  test "listing_schema handles missing coordinates gracefully" do
    @user_listing.update!(latitude: nil, longitude: nil)
    schema = listing_schema(@user_listing)
    
    assert_nil schema[:geo]
  end

  test "listing_schema handles missing price range gracefully" do
    @user_listing.update!(price_range: nil)
    schema = listing_schema(@user_listing)
    
    assert_nil schema[:priceRange]
  end

  test "listing_schema handles missing city gracefully" do
    @user_listing.update!(city: nil)
    schema = listing_schema(@user_listing)
    
    assert_nil schema[:address][:addressRegion]
  end

  test "listing_schema handles unverified listings" do
    @user_listing.update!(verified_at: nil)
    schema = listing_schema(@user_listing)
    
    assert_nil schema[:hasCredential]
  end

  test "local_business_schema works for listings with coordinates" do
    schema = local_business_schema(@user_listing)
    
    assert_equal "LocalBusiness", schema[:@type]
    assert_equal @user_listing.title, schema[:name]
    assert_equal strip_tags(@user_listing.description), schema[:description]
    assert_equal listing_url(@user_listing), schema[:url]
    
    # Check address
    assert_equal "PostalAddress", schema[:address][:@type]
    assert_equal @user_listing.location, schema[:address][:addressLocality]
    
    # Check coordinates
    assert_equal "GeoCoordinates", schema[:geo][:@type]
    assert_equal @user_listing.latitude, schema[:geo][:latitude]
    assert_equal @user_listing.longitude, schema[:geo][:longitude]
  end

  test "local_business_schema returns nil for listings without coordinates" do
    @user_listing.update!(latitude: nil, longitude: nil)
    schema = local_business_schema(@user_listing)
    
    assert_nil schema
  end

  test "breadcrumb_schema generates correct structure" do
    items = [
      { name: "Home", url: root_url },
      { name: "Listings", url: listings_url },
      { name: @user_listing.title, url: listing_url(@user_listing) }
    ]
    
    schema = breadcrumb_schema(items)
    
    assert_equal "https://schema.org", schema[:@context]
    assert_equal "BreadcrumbList", schema[:@type]
    assert_equal 3, schema[:itemListElement].length
    
    # Check first item
    first_item = schema[:itemListElement][0]
    assert_equal "ListItem", first_item[:@type]
    assert_equal 1, first_item[:position]
    assert_equal "Home", first_item[:name]
    assert_equal root_url, first_item[:item]
    
    # Check last item
    last_item = schema[:itemListElement][2]
    assert_equal "ListItem", last_item[:@type]
    assert_equal 3, last_item[:position]
    assert_equal @user_listing.title, last_item[:name]
    assert_equal listing_url(@user_listing), last_item[:item]
  end

  test "organization_schema generates correct structure" do
    schema = organization_schema
    
    assert_equal "Organization", schema[:@type]
    assert_equal "Views", schema[:name]
    assert_equal root_url, schema[:url]
    assert_equal "Find and book accommodations with amazing views", schema[:description]
    
    # Check logo
    assert_equal "ImageObject", schema[:logo][:@type]
    assert_includes schema[:logo][:url], "/icon.png"
  end

  test "render_schema_script generates correct HTML" do
    schema = { "@type": "Organization", "name": "Test" }
    result = render_schema_script(schema)
    
    assert_includes result, '<script type="application/ld+json">'
    assert_includes result, '"@type":"Organization"'
    assert_includes result, '"name":"Test"'
    assert_includes result, '</script>'
  end
end
