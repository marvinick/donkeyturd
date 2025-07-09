class ListingsController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show, :search]
  before_action :set_listing, only: [:show, :edit, :update, :destroy]
  before_action :ensure_owner, only: [:edit, :update, :destroy]

  def index
    @listings = Listing.active.includes(:user).recent
    @listings = @listings.by_view_type(params[:view_type]) if params[:view_type].present?
    @listings = @listings.by_platform(params[:platform]) if params[:platform].present?
    
    if params[:location].present?
      @listings = @listings.where("location ILIKE ?", "%#{params[:location]}%")
    end
    
    @listings = @listings.limit(12).offset((params[:page].to_i - 1) * 12) if params[:page].present?
    @listings = @listings.limit(12) if params[:page].blank?
    
    @view_types = Listing::VIEW_TYPES
    @platforms = Listing::PLATFORMS
    @total_count = Listing.active.count
  end

  def show
    @related_listings = Listing.active
                              .where(view_type: @listing.view_type)
                              .where.not(id: @listing.id)
                              .limit(3)
  end

  def new
    @listing = current_user.listings.build
  end

  def create
    @listing = current_user.listings.build(listing_params)
    
    # Debug logging
    Rails.logger.info "Images received: #{params[:listing][:images]&.length || 0}"
    
    if @listing.save
      redirect_to @listing, notice: 'Your listing has been submitted for review. Thank you!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @listing.update(listing_params)
      # Handle image deletion
      if params[:listing][:delete_image_ids].present?
        params[:listing][:delete_image_ids].each do |image_id|
          image = @listing.images.find(image_id)
          image.purge if image
        end
      end
      
      redirect_to @listing, notice: 'Listing updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @listing.destroy
    redirect_to listings_path, notice: 'Listing deleted successfully.'
  end

  def search
    @query = params[:q]
    @listings = Listing.active.includes(:user)
    
    if @query.present?
      @listings = @listings.where(
        "title ILIKE ? OR description ILIKE ? OR location ILIKE ?",
        "%#{@query}%", "%#{@query}%", "%#{@query}%"
      )
    end
    
    @listings = @listings.recent.limit(12).offset((params[:page].to_i - 1) * 12) if params[:page].present?
    @listings = @listings.recent.limit(12) if params[:page].blank?
    @total_count = @listings.count
    render :index
  end

  # External API import actions
  def search_external
    @query = params[:q]
    @results = {}
    
    if @query.present?
      @results = ApiServiceFactory.search_all_sources(@query, limit: 5)
    end
    
    render :search_external
  end
  
  def import_external
    source = params[:source]
    external_id = params[:external_id]
    
    unless ApiServiceFactory.available_sources.include?(source)
      redirect_to search_external_listings_path, alert: 'Invalid API source'
      return
    end
    
    begin
      api_key = get_api_key_for_source(source)
      unless api_key
        redirect_to search_external_listings_path, alert: "#{source.humanize} API key not configured"
        return
      end
      
      service = ApiServiceFactory.create(source, api_key: api_key)
      listing = service.import_with_photos(external_id, current_user)
      
      if listing
        redirect_to listing, notice: "Successfully imported listing from #{source.humanize}! Photos are being imported in the background."
      else
        redirect_to search_external_listings_path, alert: 'Failed to import listing'
      end
      
    rescue => e
      Rails.logger.error "Import error: #{e.message}"
      redirect_to search_external_listings_path, alert: 'Error importing listing. Please try again.'
    end
  end
  
  def api_status
    # Simple status page - just renders the view
  end

  private

  def set_listing
    @listing = Listing.find(params[:id])
  end

  def ensure_owner
    unless @listing.user == current_user
      redirect_to listings_path, alert: 'You can only edit your own listings.'
    end
  end

  def listing_params
    params.require(:listing).permit(:title, :description, :external_url, :platform, 
                                   :location, :view_type, :price_range, images: [], delete_image_ids: [])
  end

  def get_api_key_for_source(source)
    case source
    when 'tripadvisor'
      Rails.application.credentials.tripadvisor&.api_key
    when 'google_places'
      Rails.application.credentials.google&.places_api_key
    when 'foursquare'
      Rails.application.credentials.foursquare&.api_key
    end
  end
end
