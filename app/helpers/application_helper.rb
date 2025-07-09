module ApplicationHelper
  include ApiIntegrationHelper
  
  def listings_for_map
    return [] unless defined?(@all_listings_for_map)
    
    @all_listings_for_map.map do |listing|
      {
        id: listing.id,
        title: listing.title,
        latitude: listing.latitude.to_f,
        longitude: listing.longitude.to_f,
        address: listing.location,
        view_type: listing.view_type.humanize,
        platform: listing.platform_name,
        verified: listing.verified?,
        external_source: listing.external_source,
        import_status: listing.import_status
      }
    end
  end
  
  def listings_with_coordinates
    return [] unless defined?(@all_listings_for_map)
    @all_listings_for_map
  end
end
