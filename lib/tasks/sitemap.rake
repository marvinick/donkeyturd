namespace :sitemap do
  desc "Generate comprehensive sitemap for all city and view type pages"
  task :generate => :environment do
    puts "Generating comprehensive sitemap..."
    
    sitemap_content = generate_sitemap_xml
    
    # Write to public directory
    File.open(Rails.root.join('public', 'sitemap.xml'), 'w') do |file|
      file.write(sitemap_content)
    end
    
    puts "Sitemap generated successfully at public/sitemap.xml"
    puts "Total URLs: #{count_urls(sitemap_content)}"
  end
  
  desc "Generate robots.txt file"
  task :robots => :environment do
    puts "Generating robots.txt..."
    
    robots_content = generate_robots_txt
    
    File.open(Rails.root.join('public', 'robots.txt'), 'w') do |file|
      file.write(robots_content)
    end
    
    puts "Robots.txt generated successfully"
  end
  
  private
  
  def generate_sitemap_xml
    base_url = Rails.application.routes.default_url_options[:host] || 'https://yourapp.com'
    
    xml = []
    xml << '<?xml version="1.0" encoding="UTF-8"?>'
    xml << '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
    
    # Homepage
    xml << url_entry("#{base_url}/", 'daily', '1.0')
    
    # Cities index
    xml << url_entry("#{base_url}/cities", 'weekly', '0.9')
    
    # All cities
    City.with_listings.find_each do |city|
      # City main page
      xml << url_entry("#{base_url}/cities/#{city.slug}", 'weekly', '0.8', city.updated_at)
      
      # City view type pages
      city.listings_by_view_type.each do |view_type, count|
        next if count.zero?
        xml << url_entry("#{base_url}/cities/#{city.slug}/#{view_type}-views", 'weekly', '0.7', city.updated_at)
      end
    end
    
    # Global view type pages
    Listing::VIEW_TYPES.each do |view_type|
      count = Listing.active.where(view_type: view_type).count
      next if count.zero?
      xml << url_entry("#{base_url}/#{view_type}-views", 'weekly', '0.8')
    end
    
    # Individual listings
    Listing.active.find_each do |listing|
      xml << url_entry("#{base_url}/listings/#{listing.id}", 'monthly', '0.6', listing.updated_at)
    end
    
    # Country-specific city pages
    City.with_listings.distinct.pluck(:country).each do |country|
      xml << url_entry("#{base_url}/cities?country=#{URI.encode_www_form_component(country)}", 'monthly', '0.7')
    end
    
    xml << '</urlset>'
    xml.join("\n")
  end
  
  def url_entry(url, changefreq, priority, lastmod = nil)
    entry = "<url>"
    entry += "<loc>#{url}</loc>"
    entry += "<changefreq>#{changefreq}</changefreq>"
    entry += "<priority>#{priority}</priority>"
    entry += "<lastmod>#{lastmod.iso8601}</lastmod>" if lastmod
    entry += "</url>"
    entry
  end
  
  def count_urls(xml_content)
    xml_content.scan(/<url>/).size
  end
  
  def generate_robots_txt
    base_url = Rails.application.routes.default_url_options[:host] || 'https://yourapp.com'
    
    content = []
    content << "User-agent: *"
    content << "Allow: /"
    content << ""
    content << "# Disallow admin and private areas"
    content << "Disallow: /admin/"
    content << "Disallow: /users/"
    content << "Disallow: /rails/"
    content << ""
    content << "# Sitemap location"
    content << "Sitemap: #{base_url}/sitemap.xml"
    content << ""
    content << "# Crawl delay for being respectful"
    content << "Crawl-delay: 1"
    
    content.join("\n")
  end
end
