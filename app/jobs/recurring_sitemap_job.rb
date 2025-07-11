class RecurringSitemapJob < ApplicationJob
  queue_as :default
  
  def perform
    Rails.logger.info "Running recurring sitemap generation..."
    
    # Check if we need to regenerate sitemap
    last_generated = Rails.cache.read('sitemap_last_generated')
    should_regenerate = should_regenerate_sitemap?(last_generated)
    
    if should_regenerate
      Rails.logger.info "Regenerating sitemap due to: #{regeneration_reason(last_generated)}"
      
      # Generate sitemap
      SitemapGenerationJob.perform_now(
        submit_to_search_engines: true,
        ping_search_engines: true
      )
      
      # Schedule next run
      schedule_next_run
    else
      Rails.logger.info "Sitemap is up to date, skipping regeneration"
      
      # Just ping search engines to let them know we're active
      service = SitemapService.new
      service.ping_search_engines
      
      # Schedule next run
      schedule_next_run
    end
  end
  
  private
  
  def should_regenerate_sitemap?(last_generated)
    return true if last_generated.nil?
    
    # Regenerate if it's been more than 24 hours
    return true if last_generated < 24.hours.ago
    
    # Regenerate if there are new/updated cities
    return true if City.where('updated_at > ?', last_generated).exists?
    
    # Regenerate if there are new/updated listings
    return true if Listing.where('updated_at > ?', last_generated).exists?
    
    false
  end
  
  def regeneration_reason(last_generated)
    reasons = []
    
    if last_generated.nil?
      reasons << "no previous generation"
    elsif last_generated < 24.hours.ago
      reasons << "24+ hours since last generation"
    end
    
    if City.where('updated_at > ?', last_generated || 24.hours.ago).exists?
      reasons << "cities updated"
    end
    
    if Listing.where('updated_at > ?', last_generated || 24.hours.ago).exists?
      reasons << "listings updated"
    end
    
    reasons.join(", ")
  end
  
  def schedule_next_run
    # Schedule next run in 6 hours
    RecurringSitemapJob.set(wait: 6.hours).perform_later
    Rails.logger.info "Next sitemap job scheduled for #{6.hours.from_now}"
  end
end
