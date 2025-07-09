# Helper module for API integration functionality
module ApiIntegrationHelper
  def available_api_sources
    sources = []
    
    sources << 'tripadvisor' if Rails.application.credentials.tripadvisor&.api_key.present?
    sources << 'google_places' if Rails.application.credentials.google&.places_api_key.present?
    sources << 'foursquare' if Rails.application.credentials.foursquare&.api_key.present?
    
    sources
  end
  
  def api_configured?(source)
    available_api_sources.include?(source.to_s)
  end
  
  def api_status_badge(source)
    configured = api_configured?(source)
    
    content_tag :span, configured ? 'Configured' : 'Not Configured',
                class: "inline-flex px-2 py-1 text-xs font-medium rounded-full #{
                  configured ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                }"
  end
  
  def import_status_badge(status)
    case status
    when 'manual'
      content_tag :span, 'Manual', class: 'inline-flex px-2 py-1 text-xs font-medium rounded-full bg-gray-100 text-gray-800'
    when 'imported'
      content_tag :span, 'Imported', class: 'inline-flex px-2 py-1 text-xs font-medium rounded-full bg-blue-100 text-blue-800'
    when 'synced'
      content_tag :span, 'Synced', class: 'inline-flex px-2 py-1 text-xs font-medium rounded-full bg-green-100 text-green-800'
    when 'failed'
      content_tag :span, 'Failed', class: 'inline-flex px-2 py-1 text-xs font-medium rounded-full bg-red-100 text-red-800'
    else
      content_tag :span, status.humanize, class: 'inline-flex px-2 py-1 text-xs font-medium rounded-full bg-gray-100 text-gray-800'
    end
  end
end
