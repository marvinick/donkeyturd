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
  
  # Schema markup helpers
  def organization_schema
    {
      "@type": "Organization",
      "name": "Views",
      "url": root_url,
      "logo": {
        "@type": "ImageObject",
        "url": "#{request.base_url}/icon.png"
      },
      "description": "Find and book accommodations with amazing views",
      "sameAs": [
        # Add your social media URLs here
      ]
    }
  end
  
  def listing_schema(listing)
    schema = {
      "@type": "LodgingBusiness",
      "name": listing.title,
      "description": strip_tags(listing.description),
      "url": listing_url(listing),
      "address": {
        "@type": "PostalAddress",
        "addressLocality": listing.location
      }
    }
    
    # Add city/region if available
    if listing.city.present?
      schema[:address]["addressRegion"] = listing.city.name
    end
    
    # Add coordinates if available
    if listing.latitude.present? && listing.longitude.present?
      schema[:geo] = {
        "@type": "GeoCoordinates",
        "latitude": listing.latitude,
        "longitude": listing.longitude
      }
    end
    
    # Add images if available
    if listing.images.attached?
      schema[:image] = listing.images.map { |img| url_for(img) }
    end
    
    # Add price range if available
    if listing.price_range.present?
      schema[:priceRange] = listing.price_range
    end
    
    # Add amenities/features
    schema[:amenityFeature] = [
      {
        "@type": "LocationFeatureSpecification",
        "name": "#{listing.view_type_display} View",
        "value": true
      }
    ]
    
    # Add verification status
    if listing.verified?
      schema[:hasCredential] = {
        "@type": "EducationalOccupationalCredential",
        "name": "Verified Listing"
      }
    end
    
    # Add external booking link
    if listing.external_url.present?
      schema[:sameAs] = listing.external_url
    end
    
    schema
  end
  
  def breadcrumb_schema(items)
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      "itemListElement": items.map.with_index do |item, index|
        {
          "@type": "ListItem",
          "position": index + 1,
          "name": item[:name],
          "item": item[:url]
        }
      end
    }
  end
  
  def render_schema_script(schema_data)
    content_tag :script, type: "application/ld+json" do
      raw schema_data.to_json
    end
  end
  
  # Review schema (for future implementation)
  def review_schema(review)
    {
      "@type": "Review",
      "author": {
        "@type": "Person",
        "name": review.user.name
      },
      "reviewRating": {
        "@type": "Rating",
        "ratingValue": review.rating,
        "bestRating": "5"
      },
      "reviewBody": review.content,
      "datePublished": review.created_at.iso8601,
      "itemReviewed": {
        "@type": "LodgingBusiness",
        "name": review.listing.title
      }
    }
  end
  
  # Aggregate rating schema (for future implementation)
  def aggregate_rating_schema(listing)
    return nil unless listing.reviews.any?
    
    {
      "@type": "AggregateRating",
      "ratingValue": listing.average_rating,
      "reviewCount": listing.reviews.count,
      "bestRating": "5",
      "worstRating": "1"
    }
  end

  # Add LocalBusiness schema for listings with location data
  def local_business_schema(listing)
    return nil unless listing.latitude.present? && listing.longitude.present?
    
    schema = {
      "@type": "LocalBusiness",
      "name": listing.title,
      "description": strip_tags(listing.description),
      "address": {
        "@type": "PostalAddress",
        "addressLocality": listing.location
      },
      "geo": {
        "@type": "GeoCoordinates",
        "latitude": listing.latitude,
        "longitude": listing.longitude
      },
      "url": listing_url(listing)
    }
    
    # Add phone if available
    if listing.respond_to?(:phone) && listing.phone.present?
      schema["telephone"] = listing.phone
    end
    
    schema
  end
end
