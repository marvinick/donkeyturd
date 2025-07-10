module ApplicationHelper
  include ApiIntegrationHelper
  
  # Generate the correct path for a view type
  def view_type_path(view_type)
    case view_type
    when 'mountain'
      mountain_views_path
    when 'ocean'
      ocean_views_path
    when 'lake'
      lake_views_path
    when 'city'
      city_views_path
    when 'desert'
      desert_views_path
    when 'forest'
      forest_views_path
    when 'river'
      river_views_path
    when 'canyon'
      canyon_views_path
    when 'valley'
      valley_views_path
    when 'beach'
      beach_views_path
    else
      listings_path(view_type: view_type)
    end
  end
  
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
