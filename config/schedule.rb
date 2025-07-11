# Add this to your config/schedule.rb file (if using whenever gem)
# Or use this as a reference for setting up recurring jobs

# Generate sitemap every 6 hours
every 6.hours do
  runner "RecurringSitemapJob.perform_later"
end

# Generate full sitemap and submit to search engines daily at 3 AM
every 1.day, at: '3:00 am' do
  runner "SitemapGenerationJob.perform_later(submit_to_search_engines: true, ping_search_engines: true)"
end

# Weekly comprehensive sitemap generation and submission
every 1.week, at: '2:00 am' do
  runner "SitemapGenerationJob.perform_later(submit_to_search_engines: true, ping_search_engines: true)"
end
