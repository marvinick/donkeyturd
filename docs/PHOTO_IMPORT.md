# Photo Import Background Job

The `ImportPhotosJob` handles downloading and attaching photos from external APIs to imported listings.

## How It Works

1. **Triggered**: When a listing is imported from an external API via `ApiIntegrationService#import_with_photos`
2. **Downloads**: Fetches images from external URLs with proper error handling
3. **Validates**: Checks file type (JPEG, PNG, WebP, GIF) and size (max 10MB)
4. **Attaches**: Uses Active Storage to attach images to the listing
5. **Limits**: Maximum 5 photos per listing

## Supported Sources

- **TripAdvisor**: Direct image URLs from API response
- **Google Places**: Uses photo references with Google Photos API  
- **Foursquare**: Direct image URLs from photos endpoint
- **Generic**: Handles any array of image URLs

## Error Handling

- Retries up to 3 times with 5-second delays
- Skips invalid/oversized images and continues with others
- Logs all activities and errors for debugging
- Creates temporary files that are automatically cleaned up

## Usage

```ruby
# Automatically triggered when importing:
service = TripAdvisorService.new(api_key: 'your_key')
listing = service.import_with_photos('location_id', current_user)

# Manual trigger:
ImportPhotosJob.perform_later(listing.id, photo_urls_array)
```

## Configuration

Ensure your credentials are configured for API-specific photo access:

```yaml
# config/credentials.yml.enc
google:
  places_api_key: your_google_key  # Required for Google Places photos
```

## Monitoring

Check job status in development logs or use a background job monitoring tool like Sidekiq Web UI in production.
