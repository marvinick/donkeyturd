module Admin
  class SitemapController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_admin_user
    
    def index
      @sitemap_status = sitemap_status
      @recent_generations = recent_sitemap_generations
      @sitemap_files = sitemap_files_info
    end
    
    def generate
      SitemapGenerationJob.perform_later(
        submit_to_search_engines: params[:submit_to_search_engines].present?,
        ping_search_engines: params[:ping_search_engines].present?
      )
      
      redirect_to admin_sitemap_index_path, notice: "Sitemap generation job queued successfully"
    end
    
    def submit
      service = SitemapService.new
      results = service.submit_to_search_engines
      
      if results.values.any? { |r| r[:success] }
        redirect_to admin_sitemap_index_path, notice: "Sitemap submitted to search engines"
      else
        redirect_to admin_sitemap_index_path, alert: "Failed to submit sitemap to search engines"
      end
    end
    
    def ping
      service = SitemapService.new
      results = service.ping_search_engines
      
      if results.values.any? { |r| r[:success] }
        redirect_to admin_sitemap_index_path, notice: "Search engines pinged successfully"
      else
        redirect_to admin_sitemap_index_path, alert: "Failed to ping search engines"
      end
    end
    
    private
    
    def ensure_admin_user
      redirect_to root_path unless current_user.admin?
    end
    
    def sitemap_status
      {
        last_generated: Rails.cache.read('sitemap_last_generated'),
        main_sitemap_exists: File.exist?(Rails.root.join('public', 'sitemap.xml')),
        sitemaps_dir_exists: Dir.exist?(Rails.root.join('public', 'sitemaps')),
        total_urls: count_total_sitemap_urls,
        file_count: sitemap_files.count
      }
    end
    
    def recent_sitemap_generations
      # This would require a separate table to track generations
      # For now, we'll just return the last generated timestamp
      [
        {
          timestamp: Rails.cache.read('sitemap_last_generated'),
          type: 'Automatic Generation',
          urls_count: count_total_sitemap_urls
        }
      ].compact
    end
    
    def sitemap_files_info
      files = []
      
      if Dir.exist?(Rails.root.join('public', 'sitemaps'))
        Dir.glob(Rails.root.join('public', 'sitemaps', '*.xml')).each do |file|
          content = File.read(file)
          files << {
            name: File.basename(file),
            path: file,
            size: File.size(file),
            urls_count: content.scan(/<url>/).size,
            last_modified: File.mtime(file)
          }
        end
      end
      
      files
    end
    
    def sitemap_files
      Dir.glob(Rails.root.join('public', 'sitemaps', '*.xml')).map { |f| File.basename(f) }
    end
    
    def count_total_sitemap_urls
      total = 0
      sitemap_files.each do |file|
        content = File.read(Rails.root.join('public', 'sitemaps', file))
        total += content.scan(/<url>/).size
      end
      total
    rescue
      0
    end
  end
end
