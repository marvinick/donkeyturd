# Background job for importing photos from external APIs
class ImportPhotosJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: 5.seconds, attempts: 3
  
  def perform(listing_id, photo_data)
    listing = Listing.find(listing_id)
    return unless listing
    
    Rails.logger.info "Starting photo import for listing #{listing_id} from #{listing.external_source}"
    
    case listing.external_source
    when 'tripadvisor'
      import_tripadvisor_photos(listing, photo_data)
    when 'google_places'
      import_google_places_photos(listing, photo_data)
    when 'foursquare'
      import_foursquare_photos(listing, photo_data)
    else
      import_generic_photos(listing, photo_data)
    end
    
    Rails.logger.info "Completed photo import for listing #{listing_id}"
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Listing #{listing_id} not found for photo import"
  rescue => e
    Rails.logger.error "Error importing photos for listing #{listing_id}: #{e.message}"
    raise
  end
  
  private
  
  def import_tripadvisor_photos(listing, photo_urls)
    return unless photo_urls.is_a?(Array)
    
    photo_urls.each_with_index do |url, index|
      break if index >= 5 # Limit to 5 photos
      
      begin
        attach_photo_from_url(listing, url, "tripadvisor_photo_#{index + 1}")
      rescue => e
        Rails.logger.warn "Failed to import TripAdvisor photo #{index + 1}: #{e.message}"
      end
    end
  end
  
  def import_google_places_photos(listing, photo_references)
    return unless photo_references.is_a?(Array)
    
    api_key = Rails.application.credentials.google&.places_api_key
    return unless api_key
    
    photo_references.each_with_index do |photo_ref, index|
      break if index >= 5 # Limit to 5 photos
      
      begin
        # Google Places Photo API
        photo_url = "https://maps.googleapis.com/maps/api/place/photo?" +
                   "maxwidth=800&photoreference=#{photo_ref[:photo_reference]}&key=#{api_key}"
        
        attach_photo_from_url(listing, photo_url, "google_places_photo_#{index + 1}")
      rescue => e
        Rails.logger.warn "Failed to import Google Places photo #{index + 1}: #{e.message}"
      end
    end
  end
  
  def import_foursquare_photos(listing, photo_urls)
    return unless photo_urls.is_a?(Array)
    
    photo_urls.each_with_index do |url, index|
      break if index >= 5 # Limit to 5 photos
      
      begin
        attach_photo_from_url(listing, url, "foursquare_photo_#{index + 1}")
      rescue => e
        Rails.logger.warn "Failed to import Foursquare photo #{index + 1}: #{e.message}"
      end
    end
  end
  
  def import_generic_photos(listing, photo_data)
    # Handle any generic photo data format
    photos = case photo_data
             when Array
               photo_data
             when Hash
               photo_data.values.flatten
             else
               []
             end
    
    photos.each_with_index do |photo, index|
      break if index >= 5 # Limit to 5 photos
      
      begin
        url = photo.is_a?(Hash) ? photo[:url] || photo['url'] : photo.to_s
        attach_photo_from_url(listing, url, "external_photo_#{index + 1}")
      rescue => e
        Rails.logger.warn "Failed to import generic photo #{index + 1}: #{e.message}"
      end
    end
  end
  
  def attach_photo_from_url(listing, url, filename)
    return if url.blank?
    
    Rails.logger.info "Downloading photo from: #{url}"
    
    # Download the image
    response = download_image(url)
    return unless response
    
    # Determine file extension from content type or URL
    content_type = response['content-type'] || 'image/jpeg'
    extension = case content_type
                when /jpeg|jpg/
                  '.jpg'
                when /png/
                  '.png'
                when /webp/
                  '.webp'
                when /gif/
                  '.gif'
                else
                  File.extname(URI.parse(url).path).presence || '.jpg'
                end
    
    # Create a temporary file
    temp_file = Tempfile.new([filename, extension])
    temp_file.binmode
    temp_file.write(response.body)
    temp_file.rewind
    
    # Attach to listing
    listing.images.attach(
      io: temp_file,
      filename: "#{filename}#{extension}",
      content_type: content_type
    )
    
    Rails.logger.info "Successfully attached photo: #{filename}#{extension}"
    
  ensure
    temp_file&.close
    temp_file&.unlink
  end
  
  def download_image(url)
    uri = URI.parse(url)
    
    # Handle redirects and use appropriate SSL
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new(uri.request_uri)
      request['User-Agent'] = 'ViewsApp/1.0 (Photo Import)'
      request['Accept'] = 'image/*'
      
      response = http.request(request)
      
      # Handle redirects
      case response
      when Net::HTTPSuccess
        # Validate it's actually an image
        content_type = response['content-type']
        unless content_type&.start_with?('image/')
          Rails.logger.warn "URL did not return an image: #{url} (#{content_type})"
          return nil
        end
        
        # Check file size (max 10MB)
        content_length = response['content-length']&.to_i
        if content_length && content_length > 10.megabytes
          Rails.logger.warn "Image too large: #{url} (#{content_length} bytes)"
          return nil
        end
        
        response
      when Net::HTTPRedirection
        # Follow redirect
        redirect_url = response['location']
        if redirect_url
          download_image(redirect_url)
        else
          Rails.logger.warn "Redirect without location header: #{url}"
          nil
        end
      else
        Rails.logger.warn "Failed to download image: #{url} (#{response.code})"
        nil
      end
    end
  rescue => e
    Rails.logger.error "Error downloading image from #{url}: #{e.message}"
    nil
  end
end
