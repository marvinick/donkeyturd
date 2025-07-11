class SitemapGenerationJob < ApplicationJob
  queue_as :default
  
  def perform(submit_to_search_engines: true, ping_search_engines: true)
    Rails.logger.info "Starting sitemap generation job..."
    
    service = SitemapService.new
    
    # Generate all sitemaps
    service.generate_all_sitemaps
    
    # Submit to search engines if requested
    if submit_to_search_engines
      submission_results = service.submit_to_search_engines
      Rails.logger.info "Sitemap submission results: #{submission_results}"
    end
    
    # Ping search engines if requested
    if ping_search_engines
      ping_results = service.ping_search_engines
      Rails.logger.info "Search engine ping results: #{ping_results}"
    end
    
    # Update sitemap generation timestamp
    Rails.cache.write('sitemap_last_generated', Time.current)
    
    Rails.logger.info "Sitemap generation job completed successfully"
    
  rescue => e
    Rails.logger.error "Sitemap generation job failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
