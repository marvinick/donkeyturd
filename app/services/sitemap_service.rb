class SitemapService
  attr_reader :base_url, :sitemap_index_path, :sitemap_dir
  
  def initialize
    @base_url = Rails.application.routes.default_url_options[:host] || 'https://yourapp.com'
    @sitemap_dir = Rails.root.join('public', 'sitemaps')
    @sitemap_index_path = Rails.root.join('public', 'sitemap.xml')
    
    # Ensure sitemaps directory exists
    FileUtils.mkdir_p(@sitemap_dir)
  end
  
  def generate_all_sitemaps
    puts "🗺️  Generating comprehensive sitemap system..."
    
    # Generate individual sitemap files
    generate_static_sitemap
    generate_cities_sitemap
    generate_listings_sitemap
    generate_view_types_sitemap
    
    # Generate sitemap index
    generate_sitemap_index
    
    # Generate robots.txt
    generate_robots_txt
    
    puts "✅ Sitemap generation complete!"
    puts "📊 Total sitemaps: #{sitemap_files.count}"
    puts "🔗 Total URLs: #{count_total_urls}"
  end
  
  def submit_to_search_engines
    puts "🚀 Submitting sitemap to search engines..."
    
    results = {}
    
    # Google
    results[:google] = submit_to_google
    
    # Bing
    results[:bing] = submit_to_bing
    
    # Yandex
    results[:yandex] = submit_to_yandex
    
    # Log submission results
    log_submission_results(results)
    
    results
  end
  
  def ping_search_engines
    puts "🔔 Pinging search engines about sitemap update..."
    
    results = {}
    
    # Google ping
    results[:google] = ping_google
    
    # Bing ping
    results[:bing] = ping_bing
    
    results
  end
  
  private
  
  def generate_static_sitemap
    puts "📄 Generating static pages sitemap..."
    
    xml = build_xml_header
    
    # Homepage
    xml << url_entry("#{base_url}/", 'daily', '1.0')
    
    # Cities index
    xml << url_entry("#{base_url}/cities", 'weekly', '0.9')
    
    # Global view type pages
    Listing::VIEW_TYPES.each do |view_type|
      count = Listing.active.where(view_type: view_type).count
      next if count.zero?
      xml << url_entry("#{base_url}/#{view_type}-views", 'weekly', '0.8')
    end
    
    # Country-specific city pages
    City.with_listings.distinct.pluck(:country).each do |country|
      xml << url_entry("#{base_url}/cities?country=#{URI.encode_www_form_component(country)}", 'monthly', '0.7')
    end
    
    xml << '</urlset>'
    
    write_sitemap_file('static.xml', xml.join("\n"))
  end
  
  def generate_cities_sitemap
    puts "🏙️  Generating cities sitemap..."
    
    xml = build_xml_header
    
    City.with_listings.includes(:listings).find_each do |city|
      # City main page
      xml << url_entry("#{base_url}/cities/#{city.slug}", 'weekly', '0.8', city.updated_at)
      
      # City view type pages
      city.listings_by_view_type.each do |view_type, count|
        next if count.zero?
        xml << url_entry("#{base_url}/cities/#{city.slug}/#{view_type}-views", 'weekly', '0.7', city.updated_at)
      end
    end
    
    xml << '</urlset>'
    
    write_sitemap_file('cities.xml', xml.join("\n"))
  end
  
  def generate_listings_sitemap
    puts "🏠 Generating listings sitemap..."
    
    xml = build_xml_header
    
    Listing.active.find_each do |listing|
      xml << url_entry("#{base_url}/listings/#{listing.id}", 'monthly', '0.6', listing.updated_at)
    end
    
    xml << '</urlset>'
    
    write_sitemap_file('listings.xml', xml.join("\n"))
  end
  
  def generate_view_types_sitemap
    puts "🌄 Generating view types sitemap..."
    
    xml = build_xml_header
    
    # Add paginated view type pages
    Listing::VIEW_TYPES.each do |view_type|
      listings_count = Listing.active.where(view_type: view_type).count
      next if listings_count.zero?
      
      # Calculate number of pages (assuming 12 listings per page)
      per_page = 12
      total_pages = (listings_count.to_f / per_page).ceil
      
      # Add pages
      (1..total_pages).each do |page|
        url = if page == 1
          "#{base_url}/#{view_type}-views"
        else
          "#{base_url}/#{view_type}-views?page=#{page}"
        end
        
        xml << url_entry(url, 'weekly', '0.7')
      end
    end
    
    xml << '</urlset>'
    
    write_sitemap_file('view_types.xml', xml.join("\n"))
  end
  
  def generate_sitemap_index
    puts "📑 Generating sitemap index..."
    
    xml = []
    xml << '<?xml version="1.0" encoding="UTF-8"?>'
    xml << '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
    
    sitemap_files.each do |file|
      xml << '<sitemap>'
      xml << "<loc>#{base_url}/sitemaps/#{file}</loc>"
      xml << "<lastmod>#{Time.current.iso8601}</lastmod>"
      xml << '</sitemap>'
    end
    
    xml << '</sitemapindex>'
    
    File.write(@sitemap_index_path, xml.join("\n"))
  end
  
  def generate_robots_txt
    puts "🤖 Generating robots.txt..."
    
    content = []
    content << "User-agent: *"
    content << "Allow: /"
    content << ""
    content << "# Disallow admin and private areas"
    content << "Disallow: /admin/"
    content << "Disallow: /users/"
    content << "Disallow: /rails/"
    content << "Disallow: /cable/"
    content << ""
    content << "# Sitemap location"
    content << "Sitemap: #{base_url}/sitemap.xml"
    content << ""
    content << "# Crawl delay for being respectful"
    content << "Crawl-delay: 1"
    
    File.write(Rails.root.join('public', 'robots.txt'), content.join("\n"))
  end
  
  def submit_to_google
    sitemap_url = "#{base_url}/sitemap.xml"
    google_url = "https://www.google.com/webmasters/sitemaps/ping?sitemap=#{URI.encode_www_form_component(sitemap_url)}"
    
    begin
      response = Net::HTTP.get_response(URI(google_url))
      success = response.code == '200'
      
      puts success ? "✅ Google submission successful" : "❌ Google submission failed: #{response.code}"
      
      { success: success, response_code: response.code, message: response.message }
    rescue => e
      puts "❌ Google submission error: #{e.message}"
      { success: false, error: e.message }
    end
  end
  
  def submit_to_bing
    sitemap_url = "#{base_url}/sitemap.xml"
    bing_url = "https://www.bing.com/webmaster/ping.aspx?siteMap=#{URI.encode_www_form_component(sitemap_url)}"
    
    begin
      response = Net::HTTP.get_response(URI(bing_url))
      success = response.code == '200'
      
      puts success ? "✅ Bing submission successful" : "❌ Bing submission failed: #{response.code}"
      
      { success: success, response_code: response.code, message: response.message }
    rescue => e
      puts "❌ Bing submission error: #{e.message}"
      { success: false, error: e.message }
    end
  end
  
  def submit_to_yandex
    # Yandex requires API key, but we can still ping
    sitemap_url = "#{base_url}/sitemap.xml"
    yandex_url = "https://webmaster.yandex.com/ping?url=#{URI.encode_www_form_component(sitemap_url)}"
    
    begin
      response = Net::HTTP.get_response(URI(yandex_url))
      success = response.code == '200'
      
      puts success ? "✅ Yandex ping successful" : "❌ Yandex ping failed: #{response.code}"
      
      { success: success, response_code: response.code, message: response.message }
    rescue => e
      puts "❌ Yandex ping error: #{e.message}"
      { success: false, error: e.message }
    end
  end
  
  def ping_google
    sitemap_url = "#{base_url}/sitemap.xml"
    google_url = "https://www.google.com/ping?sitemap=#{URI.encode_www_form_component(sitemap_url)}"
    
    begin
      response = Net::HTTP.get_response(URI(google_url))
      success = response.code == '200'
      
      puts success ? "🔔 Google ping successful" : "❌ Google ping failed: #{response.code}"
      
      { success: success, response_code: response.code }
    rescue => e
      puts "❌ Google ping error: #{e.message}"
      { success: false, error: e.message }
    end
  end
  
  def ping_bing
    sitemap_url = "#{base_url}/sitemap.xml"
    bing_url = "https://www.bing.com/ping?sitemap=#{URI.encode_www_form_component(sitemap_url)}"
    
    begin
      response = Net::HTTP.get_response(URI(bing_url))
      success = response.code == '200'
      
      puts success ? "🔔 Bing ping successful" : "❌ Bing ping failed: #{response.code}"
      
      { success: success, response_code: response.code }
    rescue => e
      puts "❌ Bing ping error: #{e.message}"
      { success: false, error: e.message }
    end
  end
  
  def build_xml_header
    xml = []
    xml << '<?xml version="1.0" encoding="UTF-8"?>'
    xml << '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
    xml
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
  
  def write_sitemap_file(filename, content)
    File.write(@sitemap_dir.join(filename), content)
  end
  
  def sitemap_files
    Dir.glob("#{@sitemap_dir}/*.xml").map { |f| File.basename(f) }.sort
  end
  
  def count_total_urls
    total = 0
    sitemap_files.each do |file|
      content = File.read(@sitemap_dir.join(file))
      total += content.scan(/<url>/).size
    end
    total
  end
  
  def log_submission_results(results)
    puts "\n📊 Submission Results:"
    results.each do |engine, result|
      status = result[:success] ? "✅ Success" : "❌ Failed"
      puts "  #{engine.to_s.capitalize}: #{status}"
      puts "    Response: #{result[:response_code]} #{result[:message]}" if result[:response_code]
      puts "    Error: #{result[:error]}" if result[:error]
    end
  end
end
